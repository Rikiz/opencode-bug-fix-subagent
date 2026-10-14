use urlkit::percent_decode;

#[test]
fn plus_becomes_space() {
    assert_eq!(percent_decode("first+name"), "first name");
}

#[test]
fn percent_escape_becomes_space() {
    assert_eq!(percent_decode("first%20name"), "first name");
}

#[test]
fn mixed_plus_and_escape() {
    assert_eq!(percent_decode("a+b%20c"), "a b c");
}

#[test]
fn plain_text_unchanged() {
    assert_eq!(percent_decode("plain"), "plain");
}

#[test]
fn malformed_escape_is_kept() {
    assert_eq!(percent_decode("100%"), "100%");
}

#[test]
fn empty_input() {
    assert_eq!(percent_decode(""), "");
}
