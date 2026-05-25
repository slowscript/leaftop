namespace Leaftop {
    class ProcessNameCell : Gtk.Box {

        public Icon Icon { get; set; }
        public string Name { get; set; }

        private Gtk.Image icon;
        private Gtk.Inscription label;

        public ProcessNameCell(Gtk.ColumnViewCell _cell) {
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

            var gesture = new Gtk.GestureClick();
            gesture.set_button(3); // Right click
            gesture.pressed.connect((n_press, x, y) => {
                Window win = (Window)get_ancestor(typeof(Window));
                win.on_proc_right_click (_cell.position, this, (int)x, (int)y);
            });

            add_controller(gesture);
        }
    }
}
