namespace Leaftop {
    public class ChartButton : Gtk.Button {
        
        public string Title { get; set; }
        public string Status { get; set; }
        public ChartWidget chart;

        static construct {
            set_css_name ("LeaftopChartButton");
        }

        construct {
            width_request = 220;
            height_request = 50;

            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            hbox.margin_start = hbox.margin_end = hbox.margin_top = hbox.margin_bottom = 4;
            child = hbox;
            
            chart = new ChartWidget();
            chart.width_request = 70;
            chart.DrawGrid = false;
            hbox.append(chart);
            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            vbox.width_request = 150;
            hbox.append(vbox);
            
            var lblTitle = new Gtk.Inscription(null);
            var lblStatus = new Gtk.Inscription(null);
            lblStatus.nat_lines = 2;
            lblStatus.yalign = 0;
            lblStatus.add_css_class ("dim-label");
            bind_property ("Title", lblTitle, "text", GLib.BindingFlags.SYNC_CREATE);
            bind_property ("Status", lblStatus, "text", GLib.BindingFlags.SYNC_CREATE);
            vbox.append(lblTitle);
            vbox.append (lblStatus);
        }
    }
}