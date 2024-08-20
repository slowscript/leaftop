[CCode (cprefix = "LEAFTOP_", lower_case_cprefix = "leaftop_", cheader_filename = "config.h")]
namespace BuildConfig {
    public const string LOCALE_DIR;
    public const string VERSION;
}

// Passed via c_args
[CCode (cprefix = "", lower_case_cprefix = "")]
namespace BuildCArgs {
	public const string GETTEXT_PACKAGE;
}
