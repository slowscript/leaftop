namespace Leaftop {
    public class Application : Gtk.Application {
        public Application () {
            Object (application_id: "xyz.slowscript.leaftop", flags: ApplicationFlags.DEFAULT_FLAGS);
        }

        construct {
            ActionEntry[] action_entries = {
                { "about", this.on_about_action },
                { "preferences", this.on_preferences_action },
                { "quit", this.quit }
            };
            this.add_action_entries (action_entries, this);
            this.set_accels_for_action ("app.quit", {"<primary>q"});
        }

        public override void activate () {
            base.activate ();
            print("\nLeaftop v%s\n", BuildConfig.VERSION);
            print("num_processors: %u\n", get_num_processors());
        
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource("/xyz/slowscript/leaftop/style.css");
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var win = this.active_window;
            if (win == null) {
                win = new Leaftop.Window (this);
            }
            win.present ();
        }

        private void on_about_action () {
            string[] authors = { "slowscript" };
            Gtk.show_about_dialog (this.active_window,
                                   "program-name", "Leaftop",
                                   "logo-icon-name", "xyz.slowscript.leaftop",
                                   "authors", authors,
                                   "version", BuildConfig.VERSION,
                                   "copyright", "© 2026 slowscript");
        }

        private void on_preferences_action () {
            message ("app.preferences action activated");
        }
    }
}
