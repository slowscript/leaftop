namespace Leaftop {
    class DetailsGrid {
        public Gtk.Grid grid = new Gtk.Grid();
        private int column = 0;
        private int row = 0;
        
        public DetailsGrid() {
            grid.margin_top = 8;
            grid.column_spacing = 16;
        }

        public Gtk.Label add_row(string label, string value = "") {
            Gtk.Label lblLabel = new Gtk.Label(label);
            lblLabel.add_css_class("bold");
            lblLabel.halign = Gtk.Align.START;
            Gtk.Label lblValue = new Gtk.Label(value);
            lblValue.halign = Gtk.Align.START;
            grid.attach(lblLabel, column, row);
            grid.attach(lblValue, column+1, row);
            row += 1;
            return lblValue;
        }

        public void add_column() {
            column += 2;
            row = 0;
        }
    }
}