namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/window.ui")]
    public class Window : Gtk.ApplicationWindow {
        [GtkChild]
        private unowned Gtk.ColumnView column_view;
        [GtkChild]
        private unowned Gtk.Stack stackResources;
        [GtkChild]
        private unowned Gtk.Box boxPageSwitcher;
        [GtkChild]
        private unowned Gtk.Label lblCPUTotal;
        [GtkChild]
        private unowned Gtk.Label lblMemTotal;
        [GtkChild]
        private unowned Gtk.Label lblDiskTotal;
        [GtkChild]
        private unowned Gtk.Label lblNetTotal;
        [GtkChild]
        private unowned Gtk.MenuButton menuSignal;

        private Settings settings;
        private ListStore listStore;
        private ProcessWatcher watcher;
        private Gtk.SingleSelection listSelection;
        private ResourceWatcher resource_watcher;
        private Gtk.PopoverMenu proc_popover;
        private unowned ProcessWindow proc_window;

        public Window (Gtk.Application app) {
            Object (application: app);
        }

        static construct {
            typeof(ProcessorPage).ensure();
            typeof(SplitBarWidget).ensure();
        }

        construct {
            settings = new Settings("xyz.slowscript.leaftop");

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
            listSelection.selection_changed.connect(on_proc_selection_changed);
            column_view.model = listSelection;
            column_view.show_column_separators = true;
            
            var column_pid = new Gtk.ColumnViewColumn(_("PID"), column_pid_factory);
            column_pid.id = "0";
            column_pid.sorter = new Gtk.NumericSorter(new Gtk.PropertyExpression(typeof(Process), null, "PID"));;
            column_pid.fixed_width = 55;
            this.column_view.append_column(column_pid);
            var column_name = new Gtk.ColumnViewColumn(_("Process"), column_name_factory);
            column_name.id = "1";
            column_name.sorter = new Gtk.StringSorter(new Gtk.PropertyExpression(typeof(Process), null, "Name"));
            column_name.expand = true;
            this.column_view.append_column(column_name);
            var column_cpu = new Gtk.ColumnViewColumn(_("CPU%"), column_cpu_factory);
            column_cpu.id = "2";
            column_cpu.sorter = new Gtk.NumericSorter(new Gtk.PropertyExpression(typeof(Process), null, "CpuTreeUtil"));
            column_cpu.fixed_width = 50;
            this.column_view.append_column(column_cpu);
            var column_mem = new Gtk.ColumnViewColumn(_("Memory"), column_mem_factory);
            column_mem.id = "3";
            column_mem.sorter = new Gtk.NumericSorter(new Gtk.PropertyExpression(typeof(Process), null, "MemTreeUsage"));
            column_mem.fixed_width = 80;
            this.column_view.append_column(column_mem);
            var column_disk = new Gtk.ColumnViewColumn(_("Disk"), column_disk_factory);
            column_disk.id = "4";
            column_disk.sorter = new Gtk.NumericSorter(new Gtk.PropertyExpression(typeof(Process), null, "DiskTreeUtil"));
            column_disk.fixed_width = 80;
            this.column_view.append_column(column_disk);
            this.column_view.sorter.changed.connect(on_sorter_changed);
            // Restore last sort from settings
            int sort_column_id = settings.get_int("process-sort-column");
            int sort_order = settings.get_int("process-sort-order");
            this.column_view.sort_by_column((Gtk.ColumnViewColumn)column_view.columns.get_item(sort_column_id), sort_order);

            string grouping_str = settings.get_string("process-grouping");
            if (!(grouping_str in ProcessGroupings))
                grouping_str = settings.get_default_value("process-grouping").get_string();
            string grouping_v = "\"%s\"".printf(grouping_str);
            ActionEntry[] action_entries = {
                { "send-signal", this.on_send_signal, "s" },
                { "set-nice", this.on_set_nice, "i" },
                { "set-custom-nice", this.on_set_custom_nice },
                { "set-process-grouping", this.on_set_grouping, "s", grouping_v },
                { "proc-props", this.on_show_proc_props },
                { "proc-ungroup", this.on_ungroup_proc },
            };
            this.add_action_entries(action_entries, this);
            this.setup_signal_menu();

            this.watcher = new ProcessWatcher(listStore);
            this.watcher.mSorter = this.column_view.sorter;
            this.watcher.grouping = processGroupingFromString(grouping_str);
            this.watcher.startWatching();

            this.resource_watcher = new ResourceWatcher();
            this.resource_watcher.init_stack_pages(stackResources);
            this.resource_watcher.init_switcher_buttons(boxPageSwitcher);
            this.resource_watcher.lblCPUTotal = lblCPUTotal;
            this.resource_watcher.lblMemTotal = lblMemTotal;
            this.resource_watcher.lblDiskTotal = lblDiskTotal;
            this.resource_watcher.lblNetTotal = lblNetTotal;
            this.resource_watcher.start_watching();

            Menu proc_menu = new Menu();
            proc_menu.append(_("Properties"), "win.proc-props");
            proc_menu.append(_("Ungroup children"), "win.proc-ungroup");
            Menu sig_section = new Menu();
            sig_section.append(_("Stop"), "win.send-signal::sigstop");
            sig_section.append(_("Resume"), "win.send-signal::sigcont");
            sig_section.append(_("Terminate"), "win.send-signal::sigterm");
            sig_section.append(_("Kill"), "win.send-signal::sigkill");
            proc_menu.append_section (null, sig_section);
            
            proc_popover = new Gtk.PopoverMenu.from_model(proc_menu);
            proc_popover.set_parent(column_view);
            proc_popover.set_has_arrow (false);
            var right_click = new Gtk.GestureClick();
            right_click.set_button(3); // Right click
            right_click.pressed.connect((n_press, x, y) => {
                var rect = Gdk.Rectangle() {
                    x = (int)x, y = (int)y,
                    width = 1, height = 1
                };
                this.proc_popover.set_pointing_to(rect);
                this.proc_popover.popup();
            });
            column_view.add_controller(right_click);
        }

        private void on_send_signal(SimpleAction a, Variant? param) {
            string sig_name = param.get_string();
            print("Send signal %s\n", sig_name);
            Process? p = get_selected_process();
            if (p != null) {
                int sig = Utils.signalNameToInt()[sig_name];
                print("Send signal %d to %d:%s\n", sig, p.PID, p.Name);
                Posix.kill(p.PID, sig);
            }
        }

        private void on_set_nice(SimpleAction a, Variant? param) {
            int nice = param.get_int32();
            Process? p = get_selected_process();
            if (p != null) {
                print("Set nice %d to %d:%s\n", nice, p.PID, p.Name);
                int res = Posix.setpriority(Posix.PRIO_PROCESS, p.PID, nice);
                if (res != 0) {
                    if (Posix.errno in new int[]{Posix.EPERM, Posix.EACCES}) {
                        print("Need permission to set prio, trying pkexec...\n");
                        try {
                            GLib.Process.spawn_sync(null, new string[]{"pkexec", "renice", "--priority", nice.to_string(), "-p", p.PID.to_string()},
                                null, GLib.SpawnFlags.SEARCH_PATH, null);
                        } catch (SpawnError err) {
                            print("Failed to run renice: %s\n", err.message);
                            new Gtk.AlertDialog("Failed to run renice: %s\n", err.message).show(this);
                        }
                    } else
                        new Gtk.AlertDialog("Error setting priority: %s\n", Posix.strerror(Posix.errno)).show(this);
                }
            }
        }

        private void on_set_custom_nice(SimpleAction a) {
            show_input_dialog(_("Enter custom Nice value"), (res) => {
                int nice;
                if (int.try_parse(res, out nice) && nice >= -20 && nice <= 19) {
                    activate_action_variant("win.set-nice", new GLib.Variant.int32(nice));
                } else {
                    new Gtk.AlertDialog(_("Nice value must be a number between -20 (highest priority) and 19 (lowest)")).show(this);
                }
            });
        }

        private void on_set_grouping(SimpleAction a, Variant? param) {
            string grouping = param.get_string();
            print("Set grouping %s\n", grouping);
            watcher.setGrouping(processGroupingFromString(grouping));
            a.set_state(param);
            settings.set_string("process-grouping", grouping);
            Timeout.add_once(200, () => this.column_view.scroll_to(0, null, Gtk.ListScrollFlags.NONE, null));
        }

        private void on_show_proc_props(SimpleAction a) {
            Process? p = get_selected_process();
            if (p == null)
                return;
            var pw = new ProcessWindow();
            pw.set_process(p);
            pw.show();
            ((Gtk.Widget)pw).destroy.connect(() => { proc_window = null; });
            proc_window = pw;
        }

        private void on_ungroup_proc(SimpleAction a) {
            Process? p = get_selected_process();
            if (p == null)
                return;
            watcher.ungroup_children_of(p);
        }

        private void on_sorter_changed(Gtk.SorterChange change) {
            var sorter = (Gtk.ColumnViewSorter)column_view.sorter;
            var column = sorter.get_primary_sort_column();
            int id = int.parse(column.id);
            // Only write setting if it changes (it's expensive)
            if (id != settings.get_int("process-sort-column"))
                settings.set_int("process-sort-column", id);
            var order = sorter.get_primary_sort_order();
            if (order != settings.get_int("process-sort-order"))
                settings.set_int("process-sort-order", order);
        }

        private void setup_signal_menu() {
            Menu menu = new Menu();
            for (int i = 1; i < Utils.SIGNALS.length; i++)
                menu.append("%d - %s".printf(i, Utils.SIGNALS[i].up()), "win.send-signal::" + Utils.SIGNALS[i]);
            menuSignal.menu_model = menu;
        }

        private Process? get_selected_process() {
            if (listSelection.selected_item == null)
                return null;
            var itm = (Gtk.TreeListRow)listSelection.selected_item;
            return (Process)itm.item;
        }

        public void on_proc_selection_changed(uint pos, uint n) {
            if (proc_window != null) {
                var p = get_selected_process();
                if (p != null)
                    proc_window.set_process(p);
            }
        }

        public void on_proc_right_click(uint pos, Gtk.Widget parent, int x, int y) {
            this.listSelection.set_selected(pos);
            // Popup menu displayed from ColumnView-level event
            // Making the row the parent of the menu (needed for rel coords) caused theming issues
        }

        delegate void InputDialogResult(string res);
        private void show_input_dialog (string title, InputDialogResult cb) {
            var dialog = new Gtk.Dialog ();
            dialog.set_transient_for (this);
            dialog.set_modal (true);
            dialog.set_title (title);
            dialog.set_default_size(250, 50);
            dialog.add_css_class("padded-dialog");

            dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
            dialog.add_button (_("OK"), Gtk.ResponseType.OK);

            var entry = new Gtk.Entry ();
            var content = dialog.get_content_area ();
            content.margin_bottom = 10;
            content.append (entry);

            dialog.response.connect ((resp) => {
                if (resp == Gtk.ResponseType.OK)
                    cb(entry.text);
                dialog.close ();
            });

            dialog.show ();
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
            var label = new ProcessNameCell(cell);
            var expander = new Gtk.TreeExpander();
            expander.set_child(label);
            cell.set_child(expander);
        }

        private void setup_inscription_column(Object obj) {
            var cell = (Gtk.ColumnViewCell)obj;
            var label = new Gtk.Inscription("");
            label.height_request = 25;
            label.xalign = 1.0f;
            cell.set_child(label);
        }

        private List<Gtk.TreeListRow> rowsToExpand = new List<Gtk.TreeListRow>();
        private uint rowExpandJob = 0;
        private void column_name_bind(Object obj) {
            var cell = (Gtk.ColumnViewCell)obj;
            var expander = (Gtk.TreeExpander)cell.child;
            var row = (Gtk.TreeListRow)cell.item;
            expander.set_list_row(row);
            Process proc = (Process)row.item;
            expander.hide_expander = proc.Children.size == 0;
            bool newRowToExpand = false;
            if (watcher.grouping != ProcessGrouping.TREE && watcher.grouping != ProcessGrouping.FLAT
                    && (row.depth == 0) && !proc.expanded) {
                proc.expanded = true;
                rowsToExpand.append(row);
                newRowToExpand = true;
            }
            if ((rowExpandJob == 0) && newRowToExpand) {
                rowExpandJob = Idle.add_once(() => {
                    foreach (var r in rowsToExpand)
                        r.expanded = false;
                    rowsToExpand = new List<Gtk.TreeListRow>();
                    rowExpandJob = 0;
                });
            }
            ProcessNameCell widget = (ProcessNameCell)expander.child;
            widget.Icon = proc.Icon;
            widget.tooltip_text = proc.CmdLineStr;
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
