use std::env;
use std::ffi::OsString;
use std::fmt::Write as _;
use std::fs;
use std::path::{Path, PathBuf};

const MANIFEST_FILE_NAME: &str = "devc.toml";
const VERSION: &str = env!("CARGO_PKG_VERSION");

fn main() {
    if let Err(error) = run(env::args_os()) {
        eprintln!("error: {error}");
        std::process::exit(1);
    }
}

fn run<I>(args: I) -> Result<(), String>
where
    I: IntoIterator<Item = OsString>,
{
    let cli = Cli::parse(args)?;
    match cli.command.as_str() {
        "help" | "--help" | "-h" => {
            print!("{}", usage());
            Ok(())
        }
        "version" | "--version" | "-V" => {
            print!("{}", version());
            Ok(())
        }
        "init" => handle_init(cli),
        "show" => handle_show(cli),
        "compose-snippet" => handle_compose_snippet(cli),
        "just-snippet" => handle_just_snippet(cli),
        other => Err(format!("unknown command `{other}`\n\n{}", usage())),
    }
}

#[derive(Debug, Clone)]
struct Cli {
    command: String,
    project_dir: PathBuf,
    container: String,
    workspace_name: Option<String>,
    service_name: String,
    image_repo: Option<String>,
}

impl Cli {
    fn parse<I>(args: I) -> Result<Self, String>
    where
        I: IntoIterator<Item = OsString>,
    {
        let mut args = args.into_iter();
        let _program = args.next();

        let command = args
            .next()
            .ok_or_else(usage)?
            .into_string()
            .map_err(|_| "command must be valid UTF-8".to_string())?;

        let mut cli = Self {
            command,
            project_dir: env::current_dir().map_err(|e| e.to_string())?,
            container: "chae1".to_string(),
            workspace_name: None,
            service_name: "agent".to_string(),
            image_repo: None,
        };

        let mut pending_flag: Option<String> = None;
        for arg in args {
            let arg = arg
                .into_string()
                .map_err(|_| "arguments must be valid UTF-8".to_string())?;
            if let Some(flag) = pending_flag.take() {
                cli.apply_flag(&flag, &arg)?;
                continue;
            }

            match arg.as_str() {
                "--project-dir" | "--container" | "--workspace-name" | "--service-name"
                | "--image-repo" => pending_flag = Some(arg),
                "--help" | "-h" => {
                    cli.command = "help".to_string();
                }
                "--version" | "-V" => {
                    cli.command = "version".to_string();
                }
                _ => return Err(format!("unknown argument `{arg}`\n\n{}", usage())),
            }
        }

        if let Some(flag) = pending_flag {
            return Err(format!("missing value for `{flag}`"));
        }

        Ok(cli)
    }

    fn apply_flag(&mut self, flag: &str, value: &str) -> Result<(), String> {
        match flag {
            "--project-dir" => self.project_dir = PathBuf::from(value),
            "--container" => self.container = value.to_string(),
            "--workspace-name" => self.workspace_name = Some(value.to_string()),
            "--service-name" => self.service_name = value.to_string(),
            "--image-repo" => self.image_repo = Some(value.to_string()),
            _ => return Err(format!("unsupported flag `{flag}`")),
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ProjectConfig {
    manifest_path: PathBuf,
    container: String,
    workspace_name: String,
    service_name: String,
    image_repo: String,
    image_env_var: String,
    pin_file: String,
}

impl ProjectConfig {
    fn init_for(project_dir: &Path, cli: &Cli) -> Result<Self, String> {
        let workspace_name = cli
            .workspace_name
            .clone()
            .unwrap_or_else(|| default_workspace_name(project_dir));
        let container = cli.container.clone();
        let image_repo = cli
            .image_repo
            .clone()
            .unwrap_or_else(|| default_image_repo(&container));

        Ok(Self {
            manifest_path: project_dir.join(MANIFEST_FILE_NAME),
            container: container.clone(),
            workspace_name,
            service_name: cli.service_name.clone(),
            image_env_var: format!("{}_IMAGE", upper_snake(&container)),
            image_repo,
            pin_file: ".devc.local.env".to_string(),
        })
    }

    fn load_from(project_dir: &Path) -> Result<Self, String> {
        let manifest_path = find_manifest_path(project_dir)
            .ok_or_else(|| format!("could not find `{MANIFEST_FILE_NAME}` in `{}` or its parents", project_dir.display()))?;
        let contents = fs::read_to_string(&manifest_path)
            .map_err(|e| format!("failed to read {}: {e}", manifest_path.display()))?;
        let parsed = parse_manifest(&contents)?;

        let container = parsed
            .get("container")
            .cloned()
            .ok_or_else(|| "missing required key `container`".to_string())?;
        let workspace_name = parsed
            .get("workspace_name")
            .cloned()
            .ok_or_else(|| "missing required key `workspace_name`".to_string())?;
        let service_name = parsed
            .get("service_name")
            .cloned()
            .unwrap_or_else(|| "agent".to_string());
        let image_repo = parsed
            .get("image_repo")
            .cloned()
            .unwrap_or_else(|| default_image_repo(&container));
        let image_env_var = parsed
            .get("image_env_var")
            .cloned()
            .unwrap_or_else(|| format!("{}_IMAGE", upper_snake(&container)));
        let pin_file = parsed
            .get("pin_file")
            .cloned()
            .unwrap_or_else(|| ".devc.local.env".to_string());

        Ok(Self {
            manifest_path,
            container,
            workspace_name,
            service_name,
            image_repo,
            image_env_var,
            pin_file,
        })
    }

    fn manifest_contents(&self) -> String {
        let mut output = String::new();
        writeln!(
            output,
            "# Managed by `devc init`. Commit this file with the repo."
        )
        .unwrap();
        writeln!(output, "container = {:?}", self.container).unwrap();
        writeln!(output, "workspace_name = {:?}", self.workspace_name).unwrap();
        writeln!(output, "service_name = {:?}", self.service_name).unwrap();
        writeln!(output, "image_repo = {:?}", self.image_repo).unwrap();
        writeln!(output, "image_env_var = {:?}", self.image_env_var).unwrap();
        writeln!(output, "pin_file = {:?}", self.pin_file).unwrap();
        output
    }

    fn show_contents(&self) -> String {
        let mut output = String::new();
        writeln!(output, "manifest_path = {:?}", self.manifest_path.display().to_string()).unwrap();
        writeln!(output, "container = {:?}", self.container).unwrap();
        writeln!(output, "workspace_name = {:?}", self.workspace_name).unwrap();
        writeln!(output, "service_name = {:?}", self.service_name).unwrap();
        writeln!(output, "image_repo = {:?}", self.image_repo).unwrap();
        writeln!(output, "image_env_var = {:?}", self.image_env_var).unwrap();
        writeln!(output, "pin_file = {:?}", self.pin_file).unwrap();
        output
    }

    fn compose_snippet(&self) -> String {
        format!(
            "  {service_name}:\n    image: ${{{image_env_var}:-{image_repo}:latest}}\n    command: sleep infinity\n    working_dir: /workspaces/{workspace_name}\n    user: \"${{DEV_UID:-504}}:${{DEV_GID:-20}}\"\n    security_opt:\n      - no-new-privileges:true\n    cap_drop:\n      - ALL\n    read_only: true\n    tmpfs:\n      - /tmp:rw,noexec,nosuid,size=256m\n      - /run:rw,nosuid,size=16m\n    environment:\n      XDG_CACHE_HOME: /home/agent/.cache\n      XDG_CONFIG_HOME: /home/agent/.config\n      XDG_DATA_HOME: /home/agent/.local/share\n      XDG_STATE_HOME: /home/agent/.local/state\n      MISE_DATA_DIR: /home/agent/.local/share/mise\n      MISE_CACHE_DIR: /home/agent/.cache/mise\n    volumes:\n      - .:/workspaces/{workspace_name}:rw\n      - {service_name}-home:/home/agent:rw\n\nvolumes:\n  {service_name}-home:\n",
            service_name = self.service_name,
            image_env_var = self.image_env_var,
            image_repo = self.image_repo,
            workspace_name = self.workspace_name,
        )
    }

    fn just_snippet(&self) -> String {
        format!(
            "DEVCONTAINER_ENV_FILE := \"{pin_file}\"\n\n# Start the {service_name} container using the pinned image when available.\ndev-up:\n\t@if [ -f \"${{DEVCONTAINER_ENV_FILE}}\" ]; then \\\n\t\tdocker compose --env-file \"${{DEVCONTAINER_ENV_FILE}}\" up -d {service_name}; \\\n\telse \\\n\t\tdocker compose up -d {service_name}; \\\n\tfi\n\n# Open a shell in the {service_name} container.\ndev-shell:\n\t@if [ -f \"${{DEVCONTAINER_ENV_FILE}}\" ]; then \\\n\t\tdocker compose --env-file \"${{DEVCONTAINER_ENV_FILE}}\" exec -u agent {service_name} bash -l; \\\n\telse \\\n\t\tdocker compose exec -u agent {service_name} bash -l; \\\n\tfi\n",
            pin_file = self.pin_file,
            service_name = self.service_name,
        )
    }
}

fn handle_init(cli: Cli) -> Result<(), String> {
    fs::create_dir_all(&cli.project_dir)
        .map_err(|e| format!("failed to create {}: {e}", cli.project_dir.display()))?;
    let config = ProjectConfig::init_for(&cli.project_dir, &cli)?;
    fs::write(&config.manifest_path, config.manifest_contents())
        .map_err(|e| format!("failed to write {}: {e}", config.manifest_path.display()))?;
    print!("{}", config.show_contents());
    Ok(())
}

fn handle_show(cli: Cli) -> Result<(), String> {
    let config = ProjectConfig::load_from(&cli.project_dir)?;
    print!("{}", config.show_contents());
    Ok(())
}

fn handle_compose_snippet(cli: Cli) -> Result<(), String> {
    let config = ProjectConfig::load_from(&cli.project_dir)?;
    print!("{}", config.compose_snippet());
    Ok(())
}

fn handle_just_snippet(cli: Cli) -> Result<(), String> {
    let config = ProjectConfig::load_from(&cli.project_dir)?;
    print!("{}", config.just_snippet());
    Ok(())
}

fn default_workspace_name(project_dir: &Path) -> String {
    project_dir
        .file_name()
        .and_then(|name| name.to_str())
        .filter(|name| !name.is_empty())
        .unwrap_or("workspace")
        .to_string()
}

fn default_image_repo(container: &str) -> String {
    format!("ghcr.io/geoff-hill/{container}-devcontainer")
}

fn upper_snake(value: &str) -> String {
    let mut output = String::new();
    let mut previous_was_separator = true;
    for ch in value.chars() {
        if ch.is_ascii_alphanumeric() {
            output.push(ch.to_ascii_uppercase());
            previous_was_separator = false;
        } else if !previous_was_separator {
            output.push('_');
            previous_was_separator = true;
        }
    }
    output.trim_end_matches('_').to_string()
}

fn find_manifest_path(start_dir: &Path) -> Option<PathBuf> {
    for dir in start_dir.ancestors() {
        let candidate = dir.join(MANIFEST_FILE_NAME);
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    None
}

fn parse_manifest(contents: &str) -> Result<std::collections::BTreeMap<String, String>, String> {
    let mut values = std::collections::BTreeMap::new();
    for (line_number, raw_line) in contents.lines().enumerate() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        let (key, value) = line
            .split_once('=')
            .ok_or_else(|| format!("invalid manifest line {}: `{raw_line}`", line_number + 1))?;
        let key = key.trim();
        let value = value.trim();
        let parsed_value = value
            .strip_prefix('"')
            .and_then(|v| v.strip_suffix('"'))
            .ok_or_else(|| format!("manifest values must be double-quoted strings: `{raw_line}`"))?;
        values.insert(key.to_string(), parsed_value.to_string());
    }
    Ok(values)
}

fn usage() -> String {
    [
        "Usage:",
        "  devc --version",
        "  devc init [--project-dir PATH] [--container NAME] [--workspace-name NAME] [--service-name NAME] [--image-repo REPO]",
        "  devc show [--project-dir PATH]",
        "  devc compose-snippet [--project-dir PATH]",
        "  devc just-snippet [--project-dir PATH]",
        "",
        "Commands:",
        "  init             Write a project-local devc.toml manifest.",
        "  show             Display the resolved project metadata.",
        "  compose-snippet  Print a compose service snippet for the current project.",
        "  just-snippet     Print a justfile snippet for local wrapper commands.",
        "  --version, -V    Print the CLI version.",
    ]
    .join("\n")
}

fn version() -> String {
    format!("devc {VERSION}\n")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp_dir(name: &str) -> PathBuf {
        let mut path = env::temp_dir();
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        path.push(format!("devc-cli-{name}-{stamp}"));
        fs::create_dir_all(&path).unwrap();
        path
    }

    #[test]
    fn init_writes_manifest_with_defaults() {
        let project_dir = temp_dir("init");
        run([
            OsString::from("devc"),
            OsString::from("init"),
            OsString::from("--project-dir"),
            project_dir.as_os_str().to_os_string(),
        ])
        .unwrap();

        let manifest = fs::read_to_string(project_dir.join(MANIFEST_FILE_NAME)).unwrap();
        assert!(manifest.contains("container = \"chae1\""));
        assert!(manifest.contains("workspace_name = \""));
        assert!(manifest.contains("image_env_var = \"CHAE1_IMAGE\""));
    }

    #[test]
    fn init_in_container_layout_uses_leaf_directory_name() {
        let project_root = temp_dir("container-layout");
        let project_dir = project_root.join("containers").join("chae1");
        fs::create_dir_all(&project_dir).unwrap();

        run([
            OsString::from("devc"),
            OsString::from("init"),
            OsString::from("--project-dir"),
            project_dir.as_os_str().to_os_string(),
        ])
        .unwrap();

        let manifest = fs::read_to_string(project_dir.join(MANIFEST_FILE_NAME)).unwrap();
        assert!(manifest.contains("container = \"chae1\""));
        assert!(manifest.contains("workspace_name = \"chae1\""));
        assert!(manifest.contains("image_repo = \"ghcr.io/geoff-hill/chae1-devcontainer\""));
    }

    #[test]
    fn show_discovers_manifest_from_parent_directory() {
        let project_dir = temp_dir("show");
        let nested_dir = project_dir.join("apps").join("api");
        fs::create_dir_all(&nested_dir).unwrap();

        fs::write(
            project_dir.join(MANIFEST_FILE_NAME),
            r#"
container = "chae1"
workspace_name = "example_repo"
service_name = "agent"
image_repo = "ghcr.io/example/chae1-devcontainer"
image_env_var = "CHAE1_IMAGE"
pin_file = ".devc.local.env"
"#,
        )
        .unwrap();

        let config = ProjectConfig::load_from(&nested_dir).unwrap();
        assert_eq!(config.workspace_name, "example_repo");
        assert_eq!(config.service_name, "agent");
        assert_eq!(config.image_repo, "ghcr.io/example/chae1-devcontainer");
    }

    #[test]
    fn compose_snippet_uses_manifest_values() {
        let config = ProjectConfig {
            manifest_path: PathBuf::from("/tmp/devc.toml"),
            container: "chae1".to_string(),
            workspace_name: "demo_repo".to_string(),
            service_name: "agent".to_string(),
            image_repo: "ghcr.io/example/chae1-devcontainer".to_string(),
            image_env_var: "CHAE1_IMAGE".to_string(),
            pin_file: ".devc.local.env".to_string(),
        };

        let snippet = config.compose_snippet();
        assert!(snippet.contains("image: ${CHAE1_IMAGE:-ghcr.io/example/chae1-devcontainer:latest}"));
        assert!(snippet.contains("working_dir: /workspaces/demo_repo"));
        assert!(snippet.contains("- .:/workspaces/demo_repo:rw"));
    }

    #[test]
    fn just_snippet_references_pin_file_and_service_name() {
        let config = ProjectConfig {
            manifest_path: PathBuf::from("/tmp/devc.toml"),
            container: "chae1".to_string(),
            workspace_name: "demo_repo".to_string(),
            service_name: "agent".to_string(),
            image_repo: "ghcr.io/example/chae1-devcontainer".to_string(),
            image_env_var: "CHAE1_IMAGE".to_string(),
            pin_file: ".devc.local.env".to_string(),
        };

        let snippet = config.just_snippet();
        assert!(snippet.contains("DEVCONTAINER_ENV_FILE := \".devc.local.env\""));
        assert!(snippet.contains("docker compose --env-file \"${DEVCONTAINER_ENV_FILE}\" up -d agent"));
        assert!(snippet.contains("docker compose exec -u agent agent bash -l"));
    }

    #[test]
    fn version_output_matches_cargo_package_version() {
        assert_eq!(version(), format!("devc {}\n", env!("CARGO_PKG_VERSION")));
    }
}
