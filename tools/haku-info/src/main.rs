mod packages;
mod players;
mod shortcuts;
mod system;
mod theme;
fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().map(String::as_str) == Some("theme") {
        if let Err(e) = theme::run(&args[1..]) {
            eprintln!("Error: {e}");
            std::process::exit(1);
        }
        return;
    }
    if args.first().map(String::as_str) == Some("theme-palette") {
        use std::io::Read;
        let mut input = String::new();
        std::io::stdin()
            .take(1048576)
            .read_to_string(&mut input)
            .unwrap();
        let histogram = theme::histogram(&input);
        match theme::palette(&histogram) {
            Some((dark, light)) => println!("{}", serde_json::json!({"dark":dark,"light":light})),
            None => std::process::exit(1),
        }
        return;
    }
    let result = match args.first().map(String::as_str) {
        Some("system") => system::run(),
        Some("players") => players::run(),
        Some("packages") => packages::run(args.get(1).map(String::as_str).unwrap_or("")),
        Some("shortcuts") => {
            let path = args
                .get(1)
                .map(std::path::PathBuf::from)
                .unwrap_or_else(|| {
                    std::path::PathBuf::from(std::env::var_os("HOME").unwrap_or_default())
                        .join(".config/niri/config.kdl")
                });
            shortcuts::run(&path)
        }
        _ => {
            eprintln!("Usage: haku-info system|players|shortcuts [path]|packages QUERY|theme IMAGE [true|false]|theme-palette");
            std::process::exit(1);
        }
    };
    println!("{result}");
}
