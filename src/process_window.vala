namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/process_window.ui")]
    public class ProcessWindow : Gtk.Window {
        const uint UPDATE_INTERVAL = 2000;
        
        [GtkChild]
        private unowned Gtk.Box page_info;
        [GtkChild]
        private unowned Gtk.TextView txtCmdLine;

        private Process proc;

        private DetailsGrid detailsGrid;
        private Gtk.Label lblName;
        private Gtk.Label lblPID;
        private Gtk.Label lblExePath;
        private Gtk.Label lblUser;
        private Gtk.Label lblCGroup;
        private Gtk.Label lblState;
        private Gtk.Label lblPriority;
        private Gtk.Label lblThreads;
        private Gtk.Label lblCPUTime;
        private Gtk.Label lblCPUAffinity;
        private Gtk.Label lblVMem;
        private Gtk.Label lblRMem;
        private Gtk.Label lblSMem;
        private Gtk.Label lblDiskR;
        private Gtk.Label lblDiskW;

        uint updaterSource = 0;

        construct {
            detailsGrid = new DetailsGrid();
            page_info.prepend (detailsGrid.grid);
            lblName = detailsGrid.add_row ("Name", "");
            lblPID = detailsGrid.add_row ("PID", "");
            lblExePath = detailsGrid.add_row ("Executable path", "");
            lblUser = detailsGrid.add_row ("User", "");
            lblCGroup = detailsGrid.add_row ("Control group", "");
            lblState = detailsGrid.add_row ("State", "");
            lblPriority = detailsGrid.add_row (_("Priority"), "");
            lblThreads = detailsGrid.add_row (_("Threads"), "");
            lblCPUTime = detailsGrid.add_row (_("CPU time"), "");
            lblCPUAffinity = detailsGrid.add_row (_("CPU affinity"), "");
            lblVMem = detailsGrid.add_row (_("Virtual memory"), "");
            lblRMem = detailsGrid.add_row (_("Resident memory"), "");
            lblSMem = detailsGrid.add_row (_("Shared memory"), "");
            lblDiskR = detailsGrid.add_row (_("Disk read"), "");
            lblDiskW = detailsGrid.add_row (_("Disk write"), "");
            
            close_request.connect(on_close);
        }

        public void set_process(Process _proc) {
            proc = _proc;
            lblPID.label = proc.PID.to_string();
            update();
            if (updaterSource == 0)
                updaterSource = Timeout.add(UPDATE_INTERVAL, update);
        }

        bool on_close() {
            if (this.updaterSource != 0) {
                Source.remove(this.updaterSource);
                this.updaterSource = 0;
            }
            return false; // proceed as normal
        }

        bool update() {
            title = "%s (%i)".printf(proc.Name, proc.PID);
            lblName.label = proc.Name;
            lblExePath.label = proc.ExePath;
            lblUser.label = "user (1000)";
            lblCGroup.label = proc.CGroup;
            lblState.label = proc.State;
            if (proc.Prio >= 0)
                lblPriority.label = "Nice %ld (%s)".printf(proc.Prio-20, proc.Sched.to_string());
            else
                lblPriority.label = "%ld (%s)".printf(-proc.Prio-1, proc.Sched.to_string());
            lblThreads.label = proc.NumThreads.to_string();
            lblCPUTime.label = _("%.2f s").printf(proc.CpuTime / (float)ProcessWatcher.CLK_TCK);
            lblCPUAffinity.label = proc.CPUAffinity;
            lblVMem.label = Utils.humanSize(proc.MemVirtual, 2, 2);
            lblRMem.label = Utils.humanSize(proc.MemRSS);
            lblSMem.label = Utils.humanSize(proc.MemShared);
            lblDiskR.label = Utils.humanSize(proc.DiskRead/1024);
            lblDiskW.label = Utils.humanSize(proc.DiskWrite/1024);

            txtCmdLine.buffer.text = proc.CmdLine;
            return true;
        }
    }
}