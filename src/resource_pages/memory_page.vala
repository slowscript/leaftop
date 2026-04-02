namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/resource_pages/memory_page.ui")]
    class MemoryPage : Gtk.Box {
        [GtkChild]
        public unowned ChartWidget chart;
        [GtkChild]
        public unowned Gtk.Label lblMemSize;
        [GtkChild]
        public unowned Gtk.Label lblSwapTotal;

        [GtkChild]
        public unowned ChartWidget chartSwap;
        [GtkChild]
        public unowned SplitBarWidget memoryBar;

        private DetailsGrid details = new DetailsGrid();
        public Gtk.Label lblUsed;
        public Gtk.Label lblBuffer;
        public Gtk.Label lblCache;
        public Gtk.Label lblAvailable;
        public Gtk.Label lblUsedSwap;

        construct {
            memoryBar.LineColor = chartSwap.ChartColor = chart.ChartColor = {0.91f, 0.31f, 0.91f, 1.0f};
            chartSwap.ChartFill = chart.ChartFill = {0.91f, 0.31f, 0.91f, 0.5f};
            memoryBar.init({ { 0.91f, 0.31f, 0.91f, 0.7f }, { 0.91f, 0.31f, 0.91f, 0.5f }, { 0.91f, 0.31f, 0.91f, 0.3f }});
            
            append(details.grid);
            lblUsed = details.add_row (_("Used:"));
            lblBuffer = details.add_row (_("Buffer:"));
            lblCache = details.add_row (_("Cache:"));
            lblAvailable = details.add_row (_("Available:"));
            lblUsedSwap = details.add_row (_("Used swap:"));
        }

        public void init() {
            // Second details column (static info)
            details.add_column();
            var c = new GUdev.Client(null);
            var d = c.query_by_sysfs_path("/sys/devices/virtual/dmi/id");
            if (d != null) {
                int num_devices = d.get_property_as_int("MEMORY_ARRAY_NUM_DEVICES");
                int num_present = 0;
                long total_size = 0;
                Gee.ArrayList<MemoryDevice> devs = new Gee.ArrayList<MemoryDevice>();
                for (int i = 0; i < num_devices; i++) {
                    MemoryDevice dev = new MemoryDevice();
                    dev.present = d.get_property("MEMORY_DEVICE_%d_PRESENT".printf(i)) != "0";
                    if (dev.present) {
                        num_present++;
                        dev.size = long.parse (d.get_property("MEMORY_DEVICE_%d_SIZE".printf(i)));
                        total_size += dev.size;
                        dev.speed = d.get_property_as_int ("MEMORY_DEVICE_%d_CONFIGURED_SPEED_MTS".printf(i));
                        if (dev.speed == 0)
                            dev.speed = d.get_property_as_int ("MEMORY_DEVICE_%d_SPEED_MTS".printf(i));
                        dev.type = d.get_property("MEMORY_DEVICE_%d_TYPE".printf(i));
                        dev.form_factor = d.get_property("MEMORY_DEVICE_%d_FORM_FACTOR".printf(i));
                    }
                    devs.add(dev);
                }
                details.add_row(_("Installed size:"), Utils.humanSize(total_size/1024, 1, 2));
                int speed = devs.max((a,b) => b.speed - a.speed).speed;
                details.add_row (_("Speed:"), _("%d MT/s").printf(speed));
                details.add_row (_("Type:"), devs.first_match ((d) => d.type != null).type);
                details.add_row (_("Form factor:"), devs.first_match ((d) => d.form_factor != null).form_factor);
                details.add_row (_("Used slots:"), "%d/%d".printf(num_present, num_devices));
            }
        }
    }

    class MemoryDevice {
        public bool present;
        public long size;
        public int speed;
        public string type;
        public string form_factor;
    }
}