namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/preference_window.ui")]
    public class PreferenceWindow : Gtk.Window {
        [GtkChild]
        private unowned Gtk.FlowBox boxLaunchers;
        [GtkChild]
        private unowned Gtk.Button btnResetLaunchers;

        private Settings settings;
        private Gee.ArrayList<string> launchers = new Gee.ArrayList<string>();

        construct {
            btnResetLaunchers.clicked.connect(on_reset_launchers);
            
            settings = new Settings("xyz.slowscript.leaftop");
            var roots = settings.get_strv("process-group-roots");
            if (roots.length != 0)
                launchers.add_all_array(roots);
            else
                launchers.add_all_array(ProcessWatcher.ProcessLaunchersDefault);

            populate_launchers();
        }

        private void populate_launchers() {            
            boxLaunchers.remove_all();
            foreach (string r in launchers) {
                var card = new ClosableCard (r);
                card.clicked.connect(() => remove_launcher(r));
                boxLaunchers.append (card);
            }
        }

        private void on_reset_launchers() {
            settings.reset("process-group-roots");
            launchers.clear();
            launchers.add_all_array(ProcessWatcher.ProcessLaunchersDefault);
            populate_launchers();
        }

        private void remove_launcher(string launcher) {
            launchers.remove(launcher);
            string[] arr = new string[launchers.size+1];
            for (int i = 0 ; i < launchers.size; i++)
                arr[i] = launchers[i];
            arr[launchers.size] = null; // must be null terminated
            settings.set_strv("process-group-roots", arr);
            populate_launchers();
        }
    }

    public class ClosableCard : Gtk.Box {

        public signal void clicked();

        public ClosableCard(string label) {
            var lbl = new Gtk.Label(label);
            lbl.hexpand = true;
            this.append(lbl);
            var btn = new Gtk.Button.from_icon_name ("window-close");
            btn.clicked.connect(() => this.clicked());
            this.append(btn);
            this.orientation = Gtk.Orientation.HORIZONTAL;
        }

        static construct {
            set_css_name("closablecard");
        }
    }
}