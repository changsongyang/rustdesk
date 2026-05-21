use once_cell::sync::Lazy;

struct UiAssets {
    index: &'static str,
    cm: &'static str,
    install: &'static str,
    remote: &'static str,
    chatbox: &'static str,
}

static ASSETS: Lazy<UiAssets> = Lazy::new(|| UiAssets {
    index: include_str!("index.html"),
    cm: include_str!("cm.html"),
    install: include_str!("install.html"),
    remote: include_str!("remote.html"),
    chatbox: include_str!("chatbox.html"),
});

pub fn get_index() -> &'static str {
    ASSETS.index
}

pub fn get_cm() -> &'static str {
    ASSETS.cm
}

pub fn get_install() -> &'static str {
    ASSETS.install
}

pub fn get_remote() -> &'static str {
    ASSETS.remote
}

pub fn get_chatbox() -> String {
    ASSETS.chatbox.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_index() {
        assert!(!get_index().is_empty());
    }

    #[test]
    fn test_get_cm() {
        assert!(!get_cm().is_empty());
    }

    #[test]
    fn test_get_install() {
        assert!(!get_install().is_empty());
    }

    #[test]
    fn test_get_remote() {
        assert!(!get_remote().is_empty());
    }

    #[test]
    fn test_get_chatbox() {
        assert!(!get_chatbox().is_empty());
    }
}
