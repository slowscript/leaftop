namespace Leaftop {
    class ProcessNameCell : Gtk.Box {

        public Icon Icon { get; set; }
        public string Name { get; set; }

        private Gtk.Image icon;
        private Gtk.Inscription label;

        public ProcessNameCell() {
            Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 4);
            icon = new Gtk.Image();
            icon.pixel_size = 14;
            notify["Icon"].connect((p) => {
                icon.set_from_gicon(Icon);
            });

            label = new Gtk.Inscription("");
            label.hexpand = true;
            notify["Name"].connect((p) => {
                label.set_text(Name);
            });
            
            append(icon);
            append(label);
        }
    }
}
