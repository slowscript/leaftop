namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/resource_pages/processor_page.ui")]
    class ProcessorPage : Gtk.Box {
        [GtkChild]
        public unowned ChartWidget singleChart;
        [GtkChild]
        public unowned Gtk.Grid chartGrid;
        [GtkChild]
        public unowned Gtk.Stack chartStack;
        [GtkChild]
        public unowned Gtk.Label lblProcessorName;
        
        public ChartWidget[] cpuCharts;

        construct {
            singleChart.DataPoints = new float[ResourceWatcher.ChartHistoryLength];
            
            var leftClickController = new Gtk.GestureClick();
            leftClickController.button = 3;
            leftClickController.pressed.connect((n, x, y) => {
                chartStack.set_visible_child_name(chartStack.get_visible_child_name() == "page_total" ? "page_logical" : "page_total");
            });
            chartStack.add_controller(leftClickController);
        }

        public void init(int numCPUs) {

            int numCols = (int)Math.ceil(Math.sqrt(numCPUs));
            int numRows = (int)Math.ceil((double)numCPUs / numCols);
            cpuCharts = new ChartWidget[numCPUs];
            for (int i = 0; i < numCPUs; i++) {
                cpuCharts[i] = new ChartWidget();
                cpuCharts[i].DataPoints = new float[ResourceWatcher.ChartHistoryLength];
                cpuCharts[i].hexpand = true;
                cpuCharts[i].height_request = 300 / numRows;
                chartGrid.attach(cpuCharts[i], i % numCols, i / numCols);
            }
            string cpuinfo = Utils.readFile("/proc/cpuinfo");
            lblProcessorName.label = cpuinfo.split("\n")[4].split(":")[1].strip();
        }
    }
}