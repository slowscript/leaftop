namespace Leaftop {
    public class SplitBarWidget : Gtk.Widget {
        
        public Gdk.RGBA LineColor = { 0.34f, 0.58f, 0.92f, 1 };
        public Gdk.RGBA[] Colors;
        public float[] Values;

        static construct {
            set_css_name ("LeaftopSplitBarWidget");
        }

        public void init(Gdk.RGBA[] colors) {
            Colors = colors;
            Values = new float[colors.length];
        }

        public override void snapshot(Gtk.Snapshot snapshot) {
            int w = get_width();
            int h = get_height();

            // Draw border
            var rect = Graphene.Rect();
            rect.init(0, 0, w, h);
            var border = Gsk.RoundedRect();
            border.init_from_rect(rect, 0);
            snapshot.append_border(border,  {1, 1, 1, 1}, {LineColor, LineColor, LineColor, LineColor});
            
            var ctx = snapshot.append_cairo(rect);
            ctx.set_line_width(1);
            double x = 0.0;
            for (int i = 0; i < Values.length; i++) {
                double xd = w * Values[i];
                ctx.rectangle(x, 0, xd, h);
                x += xd;
                ctx.set_source_rgba(LineColor.red, LineColor.green, LineColor.blue, LineColor.alpha);
                ctx.stroke_preserve();
                var c = Colors[i];
                ctx.set_source_rgba(c.red, c.green, c.blue, c.alpha);
                ctx.fill();
            }
        }
    }
}