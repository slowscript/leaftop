namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/resource_pages/disk_page.ui")]
    class DiskPage : Gtk.Box {
        [GtkChild]
        public unowned ChartWidget chart;
        [GtkChild]
        public unowned Gtk.Label lblDiskModel;
        [GtkChild]
        public unowned Gtk.Label lblTitle;
    }
}