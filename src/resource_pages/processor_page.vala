namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/resource_pages/processor_page.ui")]
    class ProcessorPage : Gtk.Box {
        [GtkChild]
        public unowned ChartWidget chart;
        [GtkChild]
        public unowned Gtk.Label lblProcessorName;
    }
}