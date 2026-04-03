namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/resource_pages/disk_page.ui")]
    class DiskPage : Gtk.Box {
        [GtkChild]
        public unowned ChartWidget chart;
        [GtkChild]
        public unowned Gtk.Label lblDiskModel;
        [GtkChild]
        public unowned Gtk.Label lblTitle;
        [GtkChild]
        public unowned ChartWidget chartSpeed;
        [GtkChild]
        public unowned Gtk.Label lblMaxSpeed;

        private DetailsGrid details = new DetailsGrid();
        public Gtk.Label lblActiveTime;
        public Gtk.Label lblReadSpeed;
        public Gtk.Label lblWriteSpeed;
        public Gtk.Label lblTotalRead;
        public Gtk.Label lblTotalWrite;
        public Gtk.Label lblResponseTime;

        construct {
            chart.ChartColor = chartSpeed.ChartColor = {0.96f, 0.74f, 0.18f, 1.0f};
            chart.ChartFill = chartSpeed.ChartFill = {0.96f, 0.74f, 0.18f, 0.5f};
            chartSpeed.AutoScale = true;
            chartSpeed.SecondaryGraph = true;

            append(details.grid);
            lblActiveTime = details.add_row(_("Active time:"));
            lblReadSpeed = details.add_row(_("Read speed:"));
            lblWriteSpeed = details.add_row(_("Write speed:"));
            lblTotalRead = details.add_row(_("Total read:"));
            lblTotalWrite = details.add_row(_("Total written:"));
            lblResponseTime = details.add_row(_("Response time:"));
        }

        public void init(string device) {
            details.add_column();
            long sizekb = long.parse(Utils.readFile("/sys/block/%s/size".printf(device))) * DiskStats.SECTOR_SIZE / 1024;
            details.add_row(_("Size:"), Utils.humanSize(sizekb, 2, 2));
            bool removable = Utils.readFile("/sys/block/%s/removable".printf(device)) == "1";
            details.add_row(_("Removable:"), removable ? _("Yes") : _("No"));
            bool read_only = Utils.readFile("/sys/block/%s/ro".printf(device)) == "1";
            details.add_row(_("Read only:"), read_only ? _("Yes") : _("No"));
            //details.add_row(_("Type:"), "SSD");
        }
    }
}