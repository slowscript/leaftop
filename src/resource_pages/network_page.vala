namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/resource_pages/network_page.ui")]
    class NetworkPage : Gtk.Box {
        [GtkChild]
        public unowned ChartWidget chart;
        [GtkChild]
        public unowned Gtk.Label lblAdapter;
        [GtkChild]
        public unowned Gtk.Label lblTitle;
        [GtkChild]
        public unowned Gtk.Label lblMaxSpeed;

        private DetailsGrid details = new DetailsGrid();
        public Gtk.Label lblRxSpeed;
        public Gtk.Label lblTxSpeed;
        public Gtk.Label lblRxTotal;
        public Gtk.Label lblTxTotal;
        
        public Gtk.Label lblType;
        public Gtk.Label lblLinkSpeed;
        public Gtk.Label lblMACAddress;
        public Gtk.Label lblIPAddress;

        construct {
            append(details.grid);
            lblRxSpeed = details.add_row(_("Download speed:"));
            lblTxSpeed = details.add_row(_("Upload speed:"));
            lblRxTotal = details.add_row(_("Download total:"));
            lblTxTotal = details.add_row(_("Upload total:"));
            
            details.add_column();
            lblType = details.add_row(_("Type:"));
            lblLinkSpeed = details.add_row(_("Link speed:"));
            lblMACAddress = details.add_row(_("MAC address:"));
            lblIPAddress = details.add_row(_("IP addresses:"));
        }
    }
}