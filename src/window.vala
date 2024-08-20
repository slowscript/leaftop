namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/window.ui")]
    public class Window : Gtk.ApplicationWindow {
        [GtkChild]
        private unowned Gtk.ColumnView column_view;

        private ListStore listStore;
        private ProcessWatcher watcher;

        public Window (Gtk.Application app) {
            Object (application: app);
        }

        construct {
            var column_name_factory = new Gtk.SignalListItemFactory();
            column_name_factory.setup.connect (setup_expander_cell);
            column_name_factory.bind.connect(column_name_bind);
            column_name_factory.unbind.connect(column_unbind);
            var column_pid_factory = new Gtk.SignalListItemFactory();
            column_pid_factory.setup.connect(setup_label_column);
            column_pid_factory.bind.connect(column_pid_bind);
            var column_cpu_factory = new Gtk.SignalListItemFactory();
            column_cpu_factory.setup.connect(setup_label_column);
            column_cpu_factory.bind.connect(column_cpu_bind);
            column_cpu_factory.unbind.connect(column_unbind);
            var column_mem_factory = new Gtk.SignalListItemFactory();
            column_mem_factory.setup.connect(setup_label_column);
            column_mem_factory.bind.connect(column_mem_bind);
            column_mem_factory.unbind.connect(column_unbind);
            var column_disk_factory = new Gtk.SignalListItemFactory();
            column_disk_factory.setup.connect(setup_label_column);
            column_disk_factory.bind.connect(column_disk_bind);
            column_disk_factory.unbind.connect(column_unbind);

            listStore = new ListStore(typeof(Leaftop.Process));
            var model = new Gtk.TreeListModel(listStore, false, true, createModelFunc);
            var tree_sorter = new Gtk.TreeListRowSorter(column_view.sorter);
            var sort_model = new Gtk.SortListModel(model, tree_sorter);
            var selection = new Gtk.NoSelection(sort_model);
            //selection.can_unselect = true;
            column_view.model = selection;
            column_view.show_column_separators = true;
            
            var column_pid = new Gtk.ColumnViewColumn(_("PID"), column_pid_factory);
            column_pid.sorter = new PidSorter();
            this.column_view.append_column(column_pid);
            var column_name = new Gtk.ColumnViewColumn(_("Process"), column_name_factory);
            column_name.sorter = new NameSorter();
            column_name.expand = true;
            this.column_view.append_column(column_name);
            var column_cpu = new Gtk.ColumnViewColumn(_("CPU%"), column_cpu_factory);
            column_cpu.sorter = new CpuSorter();
            this.column_view.append_column(column_cpu);
            var column_mem = new Gtk.ColumnViewColumn(_("Memory"), column_mem_factory);
            column_mem.sorter = new MemSorter();
            this.column_view.append_column(column_mem);
            var column_disk = new Gtk.ColumnViewColumn(_("Disk"), column_disk_factory);
            column_disk.sorter = new DiskSorter();
            this.column_view.append_column(column_disk);

            this.watcher = new ProcessWatcher(listStore);
            this.watcher.mSorter = this.column_view.sorter;
            this.watcher.startWatching();
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
            var label = new Gtk.Label("");
            var expander = new Gtk.TreeExpander();
            expander.set_child(label);
            cell.set_child(expander);
        }

        private void setup_label_column(Object obj) {
            var cell = (Gtk.ColumnViewCell)obj;
            var label = new Gtk.Label("");
            label.use_markup = true;
            cell.set_child(label);
        }

        private void column_name_bind(Object obj) {
            var cell = (Gtk.ColumnViewCell)obj;
            var expander = (Gtk.TreeExpander)cell.child;
            Process proc;
            if (cell.item is Gtk.TreeListRow) {
                var row = (Gtk.TreeListRow)cell.item;
                expander.set_list_row(row);
                proc = (Process)row.item;
                expander.hide_expander = proc.Children.size == 0;
                //row.expanded = row.depth > 0;
            } else proc = (Process)cell.item;
            //((Gtk.Label)expander.child).label = proc.Name;
            var binding = proc.bind_property("Name", expander.child, "label", BindingFlags.SYNC_CREATE);
            obj.set_data("binding", binding);
        }
        private void column_pid_bind(Object obj) {
            var cell = (Gtk.ColumnViewCell)obj;
            var label = (Gtk.Label)cell.child;
            Process proc = (Process)((Gtk.TreeListRow)cell.item).item;
            label.label = proc.PID.to_string();
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
            bind_proc_property(obj, "DiskUseStr");
        }
        private inline void bind_proc_property(Object obj, string prop) {
            var cell = (Gtk.ColumnViewCell)obj;
            var label = (Gtk.Label)cell.child;
            Process proc = (Process)((Gtk.TreeListRow)cell.item).item;
            //FIXME: bindings are leaking memory (maybe)
            var binding = proc.bind_property(prop, label, "label", GLib.BindingFlags.SYNC_CREATE);
            obj.set_data("binding", binding);
        }
    }

    private class MemSorter : Gtk.Sorter {
        public override Gtk.Ordering compare(GLib.Object? item1, GLib.Object? item2) {
            assert_nonnull(item1);
            assert_nonnull(item2);
            Process p1 = (Process)item1;
            Process p2 = (Process)item2;
            if (p1.MemTreeUsage > p2.MemTreeUsage)
                return Gtk.Ordering.LARGER;
            else if (p2.MemTreeUsage > p1.MemTreeUsage)
                return Gtk.Ordering.SMALLER;
            else return Gtk.Ordering.EQUAL;
        }

        public override Gtk.SorterOrder get_order() {
            return Gtk.SorterOrder.PARTIAL;
        }
    }

    private class PidSorter : Gtk.Sorter {
        public override Gtk.Ordering compare(GLib.Object? item1, GLib.Object? item2) {
            assert_nonnull(item1);
            assert_nonnull(item2);
            Process p1 = (Process)item1;
            Process p2 = (Process)item2;
            if (p1.PID > p2.PID)
                return Gtk.Ordering.LARGER;
            else if (p2.PID > p1.PID)
                return Gtk.Ordering.SMALLER;
            else return Gtk.Ordering.EQUAL;
        }

        public override Gtk.SorterOrder get_order() {
            return Gtk.SorterOrder.TOTAL;
        }
    }

    private class DiskSorter : Gtk.Sorter {
        public override Gtk.Ordering compare(GLib.Object? item1, GLib.Object? item2) {
            assert_nonnull(item1);
            assert_nonnull(item2);
            Process p1 = (Process)item1;
            Process p2 = (Process)item2;
            if (p1.DiskUse > p2.DiskUse)
                return Gtk.Ordering.LARGER;
            else if (p2.DiskUse > p1.DiskUse)
                return Gtk.Ordering.SMALLER;
            else return Gtk.Ordering.EQUAL;
        }

        public override Gtk.SorterOrder get_order() {
            return Gtk.SorterOrder.PARTIAL;
        }
    }

    private class CpuSorter : Gtk.Sorter {
        public override Gtk.Ordering compare(GLib.Object? item1, GLib.Object? item2) {
            assert_nonnull(item1);
            assert_nonnull(item2);
            Process p1 = (Process)item1;
            Process p2 = (Process)item2;
            if (p1.CpuUtil > p2.CpuUtil)
                return Gtk.Ordering.LARGER;
            else if (p2.CpuUtil > p1.CpuUtil)
                return Gtk.Ordering.SMALLER;
            else return Gtk.Ordering.EQUAL;
        }

        public override Gtk.SorterOrder get_order() {
            return Gtk.SorterOrder.PARTIAL;
        }
    }

    private class NameSorter : Gtk.Sorter {
        public override Gtk.Ordering compare(GLib.Object? item1, GLib.Object? item2) {
            assert_nonnull(item1);
            assert_nonnull(item2);
            Process p1 = (Process)item1;
            Process p2 = (Process)item2;
            if (p1.Name > p2.Name)
                return Gtk.Ordering.LARGER;
            else if (p2.Name > p1.Name)
                return Gtk.Ordering.SMALLER;
            else return Gtk.Ordering.EQUAL;
        }

        public override Gtk.SorterOrder get_order() {
            return Gtk.SorterOrder.PARTIAL;
        }
    }
}
