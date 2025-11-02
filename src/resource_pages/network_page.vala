namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/resource_pages/network_page.ui")]
    class NetworkPage : Gtk.Box {
        [GtkChild]
        public unowned ChartWidget chart;
        [GtkChild]
        public unowned Gtk.Label lblAdapter;
        [GtkChild]
        public unowned Gtk.Label lblTitle;
    }
}