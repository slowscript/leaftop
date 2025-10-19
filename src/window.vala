namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/window.ui")]
    public class Window : Gtk.ApplicationWindow {
        [GtkChild]
        private unowned Gtk.ColumnView column_view;
        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.Box page_processor;
        [GtkChild]
        private unowned Gtk.Box boxPageSwitcher;

        private ListStore listStore;
        private ProcessWatcher watcher;
        private Gtk.SingleSelection listSelection;

        public Window (Gtk.Application app) {
            Object (application: app);
        }

        construct {
            var column_name_factory = new Gtk.SignalListItemFactory();
            column_name_factory.setup.connect (setup_expander_cell);
            column_name_factory.bind.connect(column_name_bind);
            column_name_factory.unbind.connect(column_unbind);
            var column_pid_factory = new Gtk.SignalListItemFactory();
            column_pid_factory.setup.connect(setup_inscription_column);
            column_pid_factory.bind.connect(column_pid_bind);
            var column_cpu_factory = new Gtk.SignalListItemFactory();
            column_cpu_factory.setup.connect(setup_inscription_column);
            column_cpu_factory.bind.connect(column_cpu_bind);
            column_cpu_factory.unbind.connect(column_unbind);
            var column_mem_factory = new Gtk.SignalListItemFactory();
            column_mem_factory.setup.connect(setup_inscription_column);
            column_mem_factory.bind.connect(column_mem_bind);
            column_mem_factory.unbind.connect(column_unbind);
            var column_disk_factory = new Gtk.SignalListItemFactory();
            column_disk_factory.setup.connect(setup_inscription_column);
            column_disk_factory.bind.connect(column_disk_bind);
            column_disk_factory.unbind.connect(column_unbind);

            listStore = new ListStore(typeof(Leaftop.Process));
            var model = new Gtk.TreeListModel(listStore, false, true, createModelFunc);
            var tree_sorter = new Gtk.TreeListRowSorter(column_view.sorter);
            var sort_model = new Gtk.SortListModel(model, tree_sorter);
            listSelection = new Gtk.SingleSelection(sort_model);
            listSelection.can_unselect = true;
            listSelection.autoselect = false;
            column_view.model = listSelection;
            column_view.show_column_separators = true;
            
            var column_pid = new Gtk.ColumnViewColumn(_("PID"), column_pid_factory);
            column_pid.sorter = new Gtk.NumericSorter(new Gtk.PropertyExpression(typeof(Process), null, "PID"));;
            column_pid.fixed_width = 50;
            this.column_view.append_column(column_pid);
            var column_name = new Gtk.ColumnViewColumn(_("Process"), column_name_factory);
            column_name.sorter = new Gtk.StringSorter(new Gtk.PropertyExpression(typeof(Process), null, "Name"));
            column_name.expand = true;
            this.column_view.append_column(column_name);
            var column_cpu = new Gtk.ColumnViewColumn(_("CPU%"), column_cpu_factory);
            column_cpu.sorter = new Gtk.NumericSorter(new Gtk.PropertyExpression(typeof(Process), null, "CpuTreeUtil"));
            column_cpu.fixed_width = 50;
            this.column_view.append_column(column_cpu);
            var column_mem = new Gtk.ColumnViewColumn(_("Memory"), column_mem_factory);
            column_mem.sorter = new Gtk.NumericSorter(new Gtk.PropertyExpression(typeof(Process), null, "MemTreeUsage"));
            column_mem.fixed_width = 70;
            this.column_view.append_column(column_mem);
            var column_disk = new Gtk.ColumnViewColumn(_("Disk"), column_disk_factory);
            column_disk.sorter = new Gtk.NumericSorter(new Gtk.PropertyExpression(typeof(Process), null, "DiskTreeUtil"));
            column_disk.fixed_width = 70;
            this.column_view.append_column(column_disk);
            // Timeout is to prevent slowdown
            //Timeout.add_once(50, () => this.column_view.sort_by_column((Gtk.ColumnViewColumn)column_view.columns.get_item(0), Gtk.SortType.ASCENDING));
            this.show.connect(() => {
                this.column_view.sort_by_column((Gtk.ColumnViewColumn)column_view.columns.get_item(3), Gtk.SortType.DESCENDING);
                Timeout.add_once(200, () => this.column_view.scroll_to(0, null, Gtk.ListScrollFlags.NONE, null));
            });

            ActionEntry[] action_entries = {
                { "send-signal", this.on_send_signal, "s" },
            };
            this.add_action_entries(action_entries, this);

            this.watcher = new ProcessWatcher(listStore);
            this.watcher.mSorter = this.column_view.sorter;
            this.watcher.startWatching();

            var chart = new ChartWidget();
            chart.height_request = 300;
            page_processor.append(chart);

            var btnProcessor = new ChartButton();
            btnProcessor.Title = _("Processor");
            btnProcessor.Status = "10 % (45 C)";
            boxPageSwitcher.append(btnProcessor);
        }

        private void on_send_signal(SimpleAction a, Variant? param) {
            string sig_name = param.get_string();
            print("Send signal %s\n", sig_name);
            if (listSelection.selected_item == null)
                return;
            var itm = (Gtk.TreeListRow)listSelection.selected_item;
            Process p = (Process)itm.item;
            if (p != null) {
                int sig = Utils.signalNameToInt()[sig_name];
                print("Send signal %d to %d:%s\n", sig, p.PID, p.Name);
                Posix.kill(p.PID, sig);
            }
        }

        private ListModel? createModelFunc(Object obj) {
            Process proc = (Process)obj;
            //print("populating list store for '%s' (%i)\n", proc.Name, proc.PID);
            var store = new ListStore(typeof(Process));
            foreach (Process c in proc.Children)
                store.append(c);
            watcher.childStores.set(proc.PID, store);
            return store;
        }

        private void setup_expander_cell(Object obj) {
            var cell = (Gtk.ColumnViewCell)obj;
            var label = new ProcessNameCell();
            var expander = new Gtk.TreeExpander();
            expander.set_child(label);
            cell.set_child(expander);
        }

        private void setup_inscription_column(Object obj) {
            var cell = (Gtk.ColumnViewCell)obj;
            var label = new Gtk.Inscription("");
            label.height_request = 25;
            cell.set_child(label);
        }

        private List<weak Gtk.TreeListRow> rowsToExpand = new List<weak Gtk.TreeListRow>();
        private uint rowExpandJob = 0;
        private void column_name_bind(Object obj) {
            var cell = (Gtk.ColumnViewCell)obj;
            var expander = (Gtk.TreeExpander)cell.child;
            var row = (Gtk.TreeListRow)cell.item;
            expander.set_list_row(row);
            Process proc = (Process)row.item;
            expander.hide_expander = proc.Children.size == 0;
            bool newRowToExpand = false;
            if ((row.depth == 0) && !proc.expanded) {
                proc.expanded = true;
                rowsToExpand.append(row);
                newRowToExpand = true;
            }
            if ((rowExpandJob == 0) && newRowToExpand) {
                rowExpandJob = Idle.add_once(() => {
                    foreach (var r in rowsToExpand)
                        if (r != null)
                            r.expanded = false;
                    rowsToExpand = new List<weak Gtk.TreeListRow>();
                    rowExpandJob = 0;
                });
            }
            ProcessNameCell widget = (ProcessNameCell)expander.child;
            widget.Icon = proc.Icon;
            widget.tooltip_text = proc.CmdLine;//[:100];
            var binding = proc.bind_property("Name", expander.child, "Name", BindingFlags.SYNC_CREATE);
            obj.set_data("binding", binding);
        }
        private void column_pid_bind(Object obj) {
            var cell = (Gtk.ColumnViewCell)obj;
            var label = (Gtk.Inscription)cell.child;
            Process proc = (Process)((Gtk.TreeListRow)cell.item).item;
            label.text = proc.PID.to_string();
        }
        private void column_mem_bind(Object obj) {
            bind_proc_property(obj, "MemString");
        }
        private void column_unbind(Object obj) {
            Binding binding = obj.get_data<Binding>("binding");
            obj.set_data("binding", null);
            binding.unbind();
            binding.unref();
        }
        private void column_cpu_bind(Object obj) {
            bind_proc_property(obj, "CpuUtilStr");
        }
        private void column_disk_bind(Object obj) {
            bind_proc_property(obj, "DiskUtilStr");
        }
        private inline void bind_proc_property(Object obj, string prop) {
            var cell = (Gtk.ColumnViewCell)obj;
            var label = (Gtk.Inscription)cell.child;
            Process proc = (Process)((Gtk.TreeListRow)cell.item).item;
            //FIXME: bindings are leaking memory (maybe)
            var binding = proc.bind_property(prop, label, "markup", GLib.BindingFlags.SYNC_CREATE);
            obj.set_data("binding", binding);
        }
    }
}
