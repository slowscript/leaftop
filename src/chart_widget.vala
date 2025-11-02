namespace Leaftop {
    public class ChartWidget : Gtk.Widget {
        
        public Gdk.RGBA ChartColor = { 0.34f, 0.58f, 0.92f, 1 };
        public Gdk.RGBA ChartFill = { 0.34f, 0.58f, 0.92f, 0.5f };
        public bool DrawGrid = true;
        public float[] DataPoints = { 0.3f, 0.5f, 0.2f, 0.8f, 0.7f };
        public uint DataStart = 0;
        public float MinValue = 0.0f;
        public float MaxValue = 1.0f;
        public bool AutoScale = false;

        static construct {
            set_css_name ("LeaftopChartWidget");
        }

        public void push_value(float val) {
            DataPoints[DataStart++] = val;
            DataStart %= DataPoints.length;

            if (AutoScale) {
                float max = 0.0f;
                foreach (float v in DataPoints)
                    if (v > max) max = v;

                MaxValue += 0.6f * (max - MaxValue);
                print("MAX: %.1f (%.1f)\n", max, MaxValue);
            }

            queue_draw();
        }

        public override void snapshot(Gtk.Snapshot snapshot) {
            int w = get_width();
            int h = get_height();

            // Draw border
            var rect = Graphene.Rect();
            rect.init(0, 0, w, h);
            var border = Gsk.RoundedRect();
            border.init_from_rect(rect, 0);
            snapshot.append_border(border,  {1, 1, 1, 1}, {ChartColor, ChartColor, ChartColor, ChartColor});
            
            // Draw grid
            var ctx = snapshot.append_cairo(rect);
            ctx.set_line_width(1);
            if (DrawGrid) {
                ctx.set_source_rgba(0, 0, 0, 0.1);
                for (int i = 1; i <= (DataPoints.length - 1)/5; i++) {
                    double x = w - w * (double)(i*5) / (DataPoints.length - 1);
                    ctx.move_to(x, 0);
                    ctx.line_to(x, h);
                }
                // TODO: horizontal grid
                ctx.stroke();
            }

            // Draw plot
            ctx.set_source_rgba(ChartColor.red, ChartColor.green, ChartColor.blue, ChartColor.alpha);
            ctx.move_to(0, h);
            for (int i = 0; i < DataPoints.length; i++) {
                int j = (i + (int)DataStart) % DataPoints.length;
                float val = DataPoints[j];
                double x = w * (double)i / (DataPoints.length - 1); 
                double y = h - h * (val - MinValue) / (MaxValue - MinValue);
                ctx.line_to(x, y);
            }
            ctx.line_to(w, h);
            ctx.stroke_preserve();
            ctx.set_source_rgba(ChartFill.red, ChartFill.green, ChartFill.blue, ChartFill.alpha);
            ctx.fill();
        }
    }
}