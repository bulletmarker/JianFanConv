// JianFanConverter - 简繁转换 (Simplified <-> Traditional Chinese converter)
// WinForms, .NET Framework 4.8, x64. Offline conversion via OpenCC (opencc.dll).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace JianFanConverter
{
    internal static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        private static void Main()
        {
            Application.ThreadException += OnThreadException;
            AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
            SetProcessDPIAware();
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // The OpenCC runtime is embedded in the exe; extract it to a per-user
            // cache directory so the app no longer needs files next to the exe.
            string runtimeDir;
            try
            {
                runtimeDir = RuntimeAssets.Ensure();
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "无法将内置的 OpenCC 运行时文件释放到磁盘：" + Environment.NewLine + Environment.NewLine +
                    ex.Message + Environment.NewLine + Environment.NewLine +
                    "请确认 %LOCALAPPDATA%\\JianFanConv 或 %TEMP%\\JianFanConv 目录可写后重试。",
                    "简繁转换", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            // Must run before the first opencc DllImport call so the loader
            // resolves opencc.dll from the extracted cache directory.
            NativeMethods.SetDllDirectory(runtimeDir);

            string missing = RuntimeAssets.FindMissingFile(runtimeDir);
            if (missing != null)
            {
                MessageBox.Show(
                    "内置运行时文件无法使用：" + missing + Environment.NewLine + Environment.NewLine +
                    "请删除缓存目录后重新启动本程序：" + Environment.NewLine + runtimeDir,
                    "简繁转换", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            OpenCCEngine.SetRuntimeDirectory(runtimeDir);
            Application.Run(new MainForm());
        }

        private static void OnThreadException(object sender, ThreadExceptionEventArgs e)
        {
            HandleException(e.Exception);
        }

        private static void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            HandleException(e.ExceptionObject as Exception);
        }

        private static void HandleException(Exception ex)
        {
            try
            {
                string log = Path.Combine(Path.GetTempPath(), "JianFanConverter-error.log");
                File.AppendAllText(log,
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + (ex == null ? "unknown error" : ex.ToString()) + Environment.NewLine);
            }
            catch
            {
                // logging must never crash the app
            }
            try
            {
                MessageBox.Show(
                    "发生错误：" + (ex == null ? "未知错误" : ex.Message) + Environment.NewLine + Environment.NewLine +
                    "详细信息已写入日志：%TEMP%\\JianFanConverter-error.log",
                    "简繁转换", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            catch
            {
                // ignore
            }
        }
    }

    internal static class NativeMethods
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool SetDllDirectory(string lpPathName);
    }

    // ------------------------------------------------------------------
    // OpenCC runtime assets are embedded as managed resources; this class
    // extracts them into a per-user cache directory at startup so the exe
    // is the only file that has to be distributed.
    // ------------------------------------------------------------------
    internal static class RuntimeAssets
    {
        // Bump this when the contents of vendor/opencc change: it is part of the
        // cache directory name, so old extractions stay untouched and unused.
        public const string RuntimeTag = "r2";

        private const string ResourcePrefix = "JianFanConverter.Runtime.";

        private static readonly string[] FileNames = new string[]
        {
            "opencc.dll",
            "s2t.json", "t2s.json",
            "s2tw.json", "tw2s.json", "s2twp.json", "tw2sp.json",
            "s2hk.json", "hk2s.json", "s2hkp.json", "hk2sp.json",
            "CJK_Compatibility_Ideographs.ocd2",
            "STPhrases.ocd2", "STCharacters.ocd2", "STPhrases_GeneratedFromRegionalPhrases.ocd2",
            "TSPhrases.ocd2", "TSCharacters.ocd2", "TSCharactersExt.ocd2",
            "TWVariants.ocd2", "TWVariantsPhrases.ocd2", "TWVariantsRev.ocd2", "TWVariantsRevPhrases.ocd2",
            "TWPhrases.ocd2", "TWPhrasesRev.ocd2",
            "HKVariants.ocd2", "HKVariantsPhrases.ocd2", "HKVariantsRev.ocd2", "HKVariantsRevPhrases.ocd2",
            "HKPhrases.ocd2", "HKPhrasesRev.ocd2"
        };

        public static string Ensure()
        {
            try
            {
                return ExtractTo(PrimaryDirectory());
            }
            catch (UnauthorizedAccessException)
            {
                return ExtractTo(FallbackDirectory());
            }
            catch (IOException)
            {
                return ExtractTo(FallbackDirectory());
            }
            catch (SecurityException)
            {
                return ExtractTo(FallbackDirectory());
            }
        }

        public static string FindMissingFile(string dir)
        {
            foreach (string f in FileNames)
            {
                if (!File.Exists(Path.Combine(dir, f)))
                    return f;
            }
            return null;
        }

        private static string PrimaryDirectory()
        {
            return Path.Combine(
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "JianFanConv"),
                "runtime-" + RuntimeTag);
        }

        private static string FallbackDirectory()
        {
            return Path.Combine(
                Path.Combine(Path.GetTempPath(), "JianFanConv"),
                "runtime-" + RuntimeTag);
        }

        private static string ExtractTo(string dir)
        {
            Directory.CreateDirectory(dir);
            Assembly asm = Assembly.GetExecutingAssembly();
            foreach (string f in FileNames)
            {
                string resourceName = ResourcePrefix + f;
                string target = Path.Combine(dir, f);
                using (Stream s = asm.GetManifestResourceStream(resourceName))
                {
                    if (s == null)
                        throw new InvalidOperationException("缺少内嵌资源：" + resourceName);
                    long length = s.Length;
                    FileInfo existing = new FileInfo(target);
                    if (existing.Exists && existing.Length == length)
                        continue;
                    WriteAsset(s, target, length);
                }
            }
            return dir;
        }

        private static void WriteAsset(Stream source, string target, long length)
        {
            string tmp = target + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                using (FileStream fs = new FileStream(tmp, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    source.CopyTo(fs);
                }
                try
                {
                    File.Move(tmp, target);
                }
                catch (IOException)
                {
                    // File.Move never overwrites, so the final name already exists:
                    // either a concurrent instance just produced it (keep it) or a
                    // stale file with a different length has to be replaced.
                    FileInfo existing = new FileInfo(target);
                    if (existing.Exists && existing.Length == length)
                        return;
                    try
                    {
                        File.Copy(tmp, target, true);
                    }
                    catch (IOException)
                    {
                        if (!new FileInfo(target).Exists) throw;
                        // Locked by a running instance; the length check on the
                        // next start retries the extraction.
                    }
                }
            }
            finally
            {
                DeleteTemp(tmp);
            }
        }

        private static void DeleteTemp(string path)
        {
            try
            {
                if (File.Exists(path)) File.Delete(path);
            }
            catch (IOException)
            {
                // A leftover .tmp file is harmless; the next run re-extracts over it.
            }
            catch (UnauthorizedAccessException)
            {
                // Cleanup must never fail the startup.
            }
        }
    }

    // ------------------------------------------------------------------
    // OpenCC P/Invoke wrapper. One cached instance per direction; the C API
    // is not thread-safe, so every call is serialized by a lock.
    // ------------------------------------------------------------------
    internal sealed class OpenCC : IDisposable
    {
        [DllImport("opencc")]
        private static extern IntPtr opencc_open_w(IntPtr configFileName);
        [DllImport("opencc")]
        private static extern int opencc_close(IntPtr opencc);
        [DllImport("opencc")]
        private static extern IntPtr opencc_convert_utf8(IntPtr opencc, IntPtr input, Int64 length);
        [DllImport("opencc")]
        private static extern void opencc_convert_utf8_free(IntPtr str);
        [DllImport("opencc")]
        private static extern IntPtr opencc_error();

        private IntPtr _handle;
        private readonly string _configPath;

        private OpenCC(string configPath, IntPtr handle)
        {
            _configPath = configPath;
            _handle = handle;
        }

        public static OpenCC Open(string configPath)
        {
            IntPtr path = Marshal.StringToHGlobalUni(configPath);
            if (path == IntPtr.Zero)
                throw new InvalidOperationException("无法为 OpenCC 配置路径分配内存：" + configPath);
            try
            {
                IntPtr h = opencc_open_w(path);
                if (h == IntPtr.Zero || h == (IntPtr)(-1))
                {
                    string err = ReadError();
                    throw new InvalidOperationException("OpenCC 打开配置失败：" + configPath +
                        (string.IsNullOrEmpty(err) ? "" : "（" + err + "）"));
                }
                return new OpenCC(configPath, h);
            }
            finally
            {
                Marshal.FreeHGlobal(path);
            }
        }

        private static string ReadError()
        {
            try
            {
                IntPtr p = opencc_error();
                if (p == IntPtr.Zero) return null;
                int len = 0;
                while (Marshal.ReadByte(p, len) != 0) len++;
                byte[] buf = new byte[len];
                Marshal.Copy(p, buf, 0, len);
                return Encoding.UTF8.GetString(buf);
            }
            catch
            {
                return null;
            }
        }

        public string Convert(string text)
        {
            if (string.IsNullOrEmpty(text)) return string.Empty;
            byte[] bytes = Encoding.UTF8.GetBytes(text);
            IntPtr input = Marshal.AllocHGlobal(bytes.Length + 1);
            try
            {
                Marshal.Copy(bytes, 0, input, bytes.Length);
                Marshal.WriteByte(input, bytes.Length, 0); // null-terminate
                IntPtr result = opencc_convert_utf8(_handle, input, bytes.Length);
                if (result == IntPtr.Zero)
                    throw new InvalidOperationException("OpenCC 转换失败（opencc_convert_utf8 返回空）");
                try
                {
                    int len = 0;
                    while (Marshal.ReadByte(result, len) != 0) len++;
                    byte[] buf = new byte[len];
                    Marshal.Copy(result, buf, 0, len);
                    return Encoding.UTF8.GetString(buf);
                }
                finally
                {
                    opencc_convert_utf8_free(result);
                }
            }
            finally
            {
                Marshal.FreeHGlobal(input);
            }
        }

        public void Dispose()
        {
            if (_handle != IntPtr.Zero && _handle != (IntPtr)(-1))
            {
                opencc_close(_handle);
                _handle = IntPtr.Zero;
            }
        }
    }

    internal enum ChineseVariant
    {
        Standard = 0,
        Taiwan = 1,
        HongKong = 2
    }

    internal static class OpenCCEngine
    {
        private static readonly object _gate = new object();
        private static string _runtimeDir;
        private static readonly Dictionary<string, OpenCC> _instances = new Dictionary<string, OpenCC>();

        public static void SetRuntimeDirectory(string dir)
        {
            lock (_gate)
            {
                _runtimeDir = dir;
            }
        }

        public static string ResolveConfig(bool s2t, ChineseVariant variant, bool localPhrases)
        {
            switch (variant)
            {
                case ChineseVariant.Taiwan:
                    if (s2t) return localPhrases ? "s2twp.json" : "s2tw.json";
                    return localPhrases ? "tw2sp.json" : "tw2s.json";
                case ChineseVariant.HongKong:
                    if (s2t) return localPhrases ? "s2hkp.json" : "s2hk.json";
                    return localPhrases ? "hk2sp.json" : "hk2s.json";
                default:
                    return s2t ? "s2t.json" : "t2s.json";
            }
        }

        public static string Convert(string text, bool s2t, ChineseVariant variant, bool localPhrases)
        {
            if (string.IsNullOrEmpty(text)) return string.Empty;
            string config = ResolveConfig(s2t, variant, localPhrases);
            lock (_gate)
            {
                if (_runtimeDir == null)
                    throw new InvalidOperationException("OpenCC 运行时目录尚未初始化");
                OpenCC engine;
                if (!_instances.TryGetValue(config, out engine))
                {
                    engine = OpenCC.Open(Path.Combine(_runtimeDir, config));
                    _instances[config] = engine;
                }
                return engine.Convert(text);
            }
        }

        public static void Shutdown()
        {
            lock (_gate)
            {
                foreach (OpenCC engine in _instances.Values)
                    engine.Dispose();
                _instances.Clear();
            }
        }
    }

    // ------------------------------------------------------------------
    // Theme tokens
    // ------------------------------------------------------------------
    internal static class Theme
    {
        public static readonly Color Background = ColorTranslator.FromHtml("#F3F4F6");
        public static readonly Color Border = ColorTranslator.FromHtml("#E5E7EB");
        public static readonly Color TextPrimary = ColorTranslator.FromHtml("#111827");
        public static readonly Color TextSecondary = ColorTranslator.FromHtml("#6B7280");
        public static readonly Color TextMuted = ColorTranslator.FromHtml("#9CA3AF");
        public static readonly Color TextBody = ColorTranslator.FromHtml("#374151");
        public static readonly Color Accent = ColorTranslator.FromHtml("#2563EB");
        public static readonly Color AccentHover = ColorTranslator.FromHtml("#EFF6FF");
        public static readonly Color Hover = ColorTranslator.FromHtml("#E5E7EB");
        public static readonly Color White = Color.White;

        public static readonly Font Base = new Font("Microsoft YaHei UI", 9.75f);
        public static readonly Font Title = new Font("Microsoft YaHei UI", 13.5f, FontStyle.Bold);
        public static readonly Font Subtitle = new Font("Microsoft YaHei UI", 8.75f);
        public static readonly Font CardHeader = new Font("Microsoft YaHei UI", 10.5f, FontStyle.Bold);
        public static readonly Font Counter = new Font("Microsoft YaHei UI", 8.75f);
        public static readonly Font Link = new Font("Microsoft YaHei UI", 9.5f);
        public static readonly Font Body = new Font("Microsoft YaHei UI", 11.5f);

        public static GraphicsPath RoundPath(Rectangle r, int radius)
        {
            GraphicsPath p = new GraphicsPath();
            int d = radius * 2;
            if (d <= 0 || r.Width <= 0 || r.Height <= 0 || r.Width < d || r.Height < d)
            {
                if (r.Width > 0 && r.Height > 0) p.AddRectangle(r);
                return p;
            }
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }
    }

    // ------------------------------------------------------------------
    // Custom painted controls
    // ------------------------------------------------------------------
    internal sealed class HeaderPanel : Panel
    {
        public HeaderPanel()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = Theme.White;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            using (Pen p = new Pen(Theme.Border))
                e.Graphics.DrawLine(p, 0, Height - 1, Width, Height - 1);
        }
    }

    internal sealed class RoundedCard : Panel
    {
        public RoundedCard()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = Theme.White;
            Padding = new Padding(1);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
            using (GraphicsPath path = Theme.RoundPath(r, 10))
            {
                using (SolidBrush b = new SolidBrush(Theme.White))
                    e.Graphics.FillPath(b, path);
                using (Pen p = new Pen(Theme.Border))
                    e.Graphics.DrawPath(p, path);
            }
        }
    }

    internal sealed class SegmentedControl : Control
    {
        private readonly string[] _labels;
        private int _selected;
        private int _hover = -1;

        public event EventHandler SelectionChanged;

        public SegmentedControl(string[] labels, string accessibleName, int minSegmentWidth)
        {
            _labels = labels == null ? new string[0] : labels;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = Theme.White;
            Font = Theme.Base;
            Height = 36;
            int width = 0;
            using (Graphics g = CreateGraphics())
            {
                foreach (string s in _labels)
                    width += Math.Max(minSegmentWidth, TextRenderer.MeasureText(g, s, Font).Width + 24);
            }
            Width = width;
            // UIA bridges the accessible Name from the window caption (Text),
            // not AccessibleName; OnPaint never draws Text so this is safe.
            Text = accessibleName;
            AccessibleName = accessibleName;
            TabStop = true;
        }

        public int Count
        {
            get { return _labels.Length; }
        }

        public int SelectedIndex
        {
            get { return _selected; }
            set
            {
                if (value < 0) value = 0;
                if (value > _labels.Length - 1) value = Math.Max(0, _labels.Length - 1);
                if (_selected != value) { _selected = value; Invalidate(); }
            }
        }

        public string SelectedLabel
        {
            get { return _labels.Length == 0 ? string.Empty : _labels[_selected]; }
        }

        private int SegmentWidth
        {
            get { return _labels.Length == 0 ? Width : Width / _labels.Length; }
        }

        private Rectangle SegmentRect(int index)
        {
            int segW = SegmentWidth;
            int x = index * segW;
            int w = index == _labels.Length - 1 ? Width - x : segW;
            return new Rectangle(x, 0, w, Height);
        }

        private int HitSegment(Point pt)
        {
            if (pt.X < 0 || pt.X >= Width || _labels.Length == 0) return -1;
            int index = pt.X / Math.Max(1, SegmentWidth);
            if (index >= _labels.Length) index = _labels.Length - 1;
            return index;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (_labels.Length == 0) return;
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle full = new Rectangle(0, 0, Width - 1, Height - 1);
            using (GraphicsPath outer = Theme.RoundPath(full, 8))
            {
                System.Drawing.Region oldClip = e.Graphics.Clip;
                e.Graphics.SetClip(outer);
                for (int i = 0; i < _labels.Length; i++)
                {
                    Rectangle seg = SegmentRect(i);
                    if (i == _selected)
                    {
                        using (SolidBrush b = new SolidBrush(Theme.Accent))
                            e.Graphics.FillRectangle(b, seg);
                    }
                    else if (i == _hover)
                    {
                        Rectangle h = new Rectangle(seg.X + 2, 2, seg.Width - 4, Height - 4);
                        using (GraphicsPath hp = Theme.RoundPath(h, 6))
                        using (SolidBrush b = new SolidBrush(Theme.Hover))
                            e.Graphics.FillPath(b, hp);
                    }
                }
                e.Graphics.Clip = oldClip;
                using (Pen p = new Pen(Theme.Border))
                    e.Graphics.DrawPath(p, outer);
            }
            for (int i = 0; i < _labels.Length; i++)
            {
                Rectangle seg = SegmentRect(i);
                Color fore = i == _selected ? Theme.White : Theme.TextBody;
                TextRenderer.DrawText(e.Graphics, _labels[i], Font, seg, fore,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine);
            }
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            int h = HitSegment(e.Location);
            if (h != _hover) { _hover = h; Invalidate(); }
            base.OnMouseMove(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            if (_hover != -1) { _hover = -1; Invalidate(); }
            base.OnMouseLeave(e);
        }

        protected override void OnMouseClick(MouseEventArgs e)
        {
            int h = HitSegment(e.Location);
            if (h >= 0 && h != _selected)
            {
                _selected = h;
                Invalidate();
                RaiseChanged();
            }
            base.OnMouseClick(e);
        }

        protected override bool IsInputKey(Keys keyData)
        {
            if (keyData == Keys.Left || keyData == Keys.Right) return true;
            return base.IsInputKey(keyData);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Left && _selected > 0)
            {
                _selected--;
                Invalidate();
                RaiseChanged();
                e.Handled = true;
            }
            else if (e.KeyCode == Keys.Right && _selected < _labels.Length - 1)
            {
                _selected++;
                Invalidate();
                RaiseChanged();
                e.Handled = true;
            }
            base.OnKeyDown(e);
        }

        private void RaiseChanged()
        {
            EventHandler handler = SelectionChanged;
            if (handler != null) handler(this, EventArgs.Empty);
        }
    }

    internal sealed class FlatButton : Control
    {
        private bool _hover;
        private bool _checked;

        public FlatButton()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = Theme.White;
            Font = Theme.Base;
            TabStop = true;
        }

        public bool Checked
        {
            get { return _checked; }
            set { if (_checked != value) { _checked = value; Invalidate(); } }
        }

        public void SizeToText()
        {
            Size s = TextRenderer.MeasureText(Text, Font);
            Width = s.Width + 32;
            Height = 34;
        }

        protected override bool IsInputKey(Keys keyData)
        {
            if (keyData == Keys.Space || keyData == Keys.Enter) return true;
            return base.IsInputKey(keyData);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter)
            {
                OnClick(EventArgs.Empty);
                e.Handled = true;
            }
            base.OnKeyDown(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
            using (GraphicsPath path = Theme.RoundPath(r, 8))
            {
                using (SolidBrush b = new SolidBrush(_checked ? Theme.Accent : (_hover ? Theme.Hover : Theme.Background)))
                    e.Graphics.FillPath(b, path);
            }
            TextRenderer.DrawText(e.Graphics, Text, Font, r, _checked ? Theme.White : Theme.TextBody,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine);
        }

        protected override void OnMouseEnter(EventArgs e) { _hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hover = false; Invalidate(); base.OnMouseLeave(e); }
    }

    internal sealed class LinkButton : Control
    {
        private bool _hover;

        public LinkButton()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = Theme.White;
            Font = Theme.Link;
            TabStop = true;
        }

        public void SizeToText()
        {
            Size s = TextRenderer.MeasureText(Text, Font);
            Width = s.Width + 20;
            Height = 26;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (_hover)
            {
                e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
                Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
                using (GraphicsPath path = Theme.RoundPath(r, 6))
                using (SolidBrush b = new SolidBrush(Theme.AccentHover))
                    e.Graphics.FillPath(b, path);
            }
            TextRenderer.DrawText(e.Graphics, Text, Font,
                new Rectangle(0, 0, Width, Height), Theme.Accent,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine);
        }

        protected override void OnMouseEnter(EventArgs e) { _hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hover = false; Invalidate(); base.OnMouseLeave(e); }
    }

    internal sealed class FlatCheckBox : Control
    {
        private bool _checked;
        private bool _hover;

        public event EventHandler CheckedChanged;

        public FlatCheckBox()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = Theme.White;
            Font = Theme.Base;
            Height = 26;
            TabStop = true;
            Cursor = Cursors.Hand;
        }

        public bool Checked
        {
            get { return _checked; }
            set
            {
                if (_checked != value) { _checked = value; Invalidate(); }
            }
        }

        public void SizeToText()
        {
            Size s = TextRenderer.MeasureText(Text, Font);
            Height = Math.Max(26, s.Height);
            Width = 24 + s.Width + 6;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            int box = 16;
            int top = (Height - box) / 2;
            bool on = _checked && Enabled;
            Rectangle r = new Rectangle(0, top, box, box);
            using (GraphicsPath path = Theme.RoundPath(r, 4))
            {
                using (SolidBrush b = new SolidBrush(on ? Theme.Accent : (_hover && Enabled ? Theme.Hover : Theme.White)))
                    e.Graphics.FillPath(b, path);
                using (Pen p = new Pen(on ? Theme.Accent : Theme.Border))
                    e.Graphics.DrawPath(p, path);
            }
            if (on)
            {
                using (Pen p = new Pen(Theme.White, 2f))
                {
                    p.StartCap = LineCap.Round;
                    p.EndCap = LineCap.Round;
                    p.LineJoin = LineJoin.Round;
                    e.Graphics.DrawLines(p, new PointF[]
                    {
                        new PointF(4f, top + 8f),
                        new PointF(7f, top + 11f),
                        new PointF(12f, top + 4.5f)
                    });
                }
            }
            Color fore = Enabled ? Theme.TextBody : Theme.TextMuted;
            TextRenderer.DrawText(e.Graphics, Text, Font,
                new Rectangle(24, 0, Width - 24, Height), fore,
                TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine);
        }

        protected override void OnEnabledChanged(EventArgs e)
        {
            Invalidate();
            base.OnEnabledChanged(e);
        }

        protected override void OnMouseEnter(EventArgs e) { _hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hover = false; Invalidate(); base.OnMouseLeave(e); }

        protected override void OnMouseClick(MouseEventArgs e)
        {
            if (Enabled && e.Button == MouseButtons.Left)
            {
                _checked = !_checked;
                Invalidate();
                RaiseChanged();
            }
            base.OnMouseClick(e);
        }

        protected override bool IsInputKey(Keys keyData)
        {
            if (keyData == Keys.Space) return true;
            return base.IsInputKey(keyData);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Space && Enabled)
            {
                _checked = !_checked;
                Invalidate();
                RaiseChanged();
                e.Handled = true;
            }
            base.OnKeyDown(e);
        }

        private void RaiseChanged()
        {
            EventHandler handler = CheckedChanged;
            if (handler != null) handler(this, EventArgs.Empty);
        }
    }

    // ------------------------------------------------------------------
    // Main form
    // ------------------------------------------------------------------
    internal sealed class AutoScrollTextBox : TextBox
    {
        [DllImport("user32.dll")]
        private static extern bool ShowScrollBar(IntPtr hWnd, int wBar, bool bShow);
        private const int SB_VERT = 1;
        private bool _barVisible = true;

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            UpdateScrollBar();
        }

        protected override void OnTextChanged(EventArgs e)
        {
            base.OnTextChanged(e);
            UpdateScrollBar();
        }

        protected override void OnSizeChanged(EventArgs e)
        {
            base.OnSizeChanged(e);
            UpdateScrollBar();
        }

        protected override void OnFontChanged(EventArgs e)
        {
            base.OnFontChanged(e);
            UpdateScrollBar();
        }

        private void UpdateScrollBar()
        {
            if (!IsHandleCreated || !Visible) return;

            bool need;
            if (Text.Length > 20000)
            {
                need = true;
            }
            else
            {
                int width = Math.Max(20, ClientSize.Width - 4);
                Size measured = TextRenderer.MeasureText(
                    Text + " ",
                    Font,
                    new Size(width, int.MaxValue),
                    TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);
                need = measured.Height > ClientSize.Height;
            }

            if (need != _barVisible)
            {
                _barVisible = need;
                ShowScrollBar(Handle, SB_VERT, need);
            }
        }
    }

    internal sealed class MainForm : Form
    {
        private bool _s2t = true;
        private ChineseVariant _variant = ChineseVariant.Taiwan;
        private bool _localPhrases = true;
        private int _version;
        private readonly System.Windows.Forms.Timer _debounce;

        private TextBox _txtInput;
        private TextBox _txtOutput;
        private Label _lblInputCount;
        private Label _lblOutputCount;
        private Label _lblStatus;
        private Label _lblEngine;
        private Label _lblPlaceholder;
        private HeaderPanel _header;
        private Panel _toolbar;
        private Panel _status;
        private Label _lblTitle;
        private Label _lblSubtitle;
        private Panel _headLeft;
        private Panel _headRight;
        private Label _lblInputTitle;
        private Label _lblOutputTitle;
        private SegmentedControl _seg;
        private SegmentedControl _regionSeg;
        private FlatCheckBox _chkPhrases;
        private FlatButton _btnClear;
        private FlatButton _btnPin;
        private LinkButton _btnPaste;
        private LinkButton _btnCopy;

        public MainForm()
        {
            Text = "简繁转换";
            ClientSize = new Size(1040, 660);
            MinimumSize = new Size(760, 480);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Theme.Background;
            Font = Theme.Base;
            DoubleBuffered = true;

            _debounce = new System.Windows.Forms.Timer { Interval = 200 };
            _debounce.Tick += OnDebounceTick;

            BuildUi();

            FormClosed += delegate { OpenCCEngine.Shutdown(); };
        }

        private void BuildUi()
        {
            // ---- header -------------------------------------------------
            _header = new HeaderPanel { Dock = DockStyle.Top, Height = 64 };

            _lblTitle = new Label
            {
                Text = "简繁转换",
                AutoSize = true,
                Font = Theme.Title,
                ForeColor = Theme.TextPrimary,
                Location = new Point(20, 9),
                BackColor = Color.Transparent
            };
            _lblSubtitle = new Label
            {
                Text = "OpenCC 本地离线",
                AutoSize = true,
                Font = Theme.Subtitle,
                ForeColor = Theme.TextSecondary,
                Location = new Point(20, 38),
                BackColor = Color.Transparent
            };

            _btnClear = new FlatButton { Text = "清空", TabIndex = 4, AccessibleName = "清空" };
            _btnClear.SizeToText();
            _btnClear.Click += delegate { ClearAll(); };

            _btnPin = new FlatButton { Text = "置顶", TabIndex = 8, AccessibleName = "置顶" };
            _btnPin.SizeToText();
            _btnPin.Click += OnPinToggled;

            _header.Controls.Add(_btnClear);
            _header.Controls.Add(_btnPin);
            _header.Controls.Add(_lblSubtitle);
            _header.Controls.Add(_lblTitle);

            // ---- toolbar: direction + region + phrases ------------------
            _toolbar = new HeaderPanel { Dock = DockStyle.Top, Height = 52 };

            _seg = new SegmentedControl(new string[] { "简 → 繁", "繁 → 简" }, "方向切换", 96);
            _seg.TabIndex = 1;
            _seg.SelectionChanged += OnDirectionChanged;

            _regionSeg = new SegmentedControl(new string[] { "标准", "台湾", "香港" }, "繁体地区", 64);
            _regionSeg.TabIndex = 6;
            _regionSeg.SelectedIndex = (int)_variant;
            _regionSeg.SelectionChanged += OnVariantChanged;

            _chkPhrases = new FlatCheckBox { Text = "地区用词", TabIndex = 7, AccessibleName = "地区用词" };
            _chkPhrases.SizeToText();
            _chkPhrases.Checked = _localPhrases;
            _chkPhrases.CheckedChanged += OnPhrasesChanged;

            _toolbar.Controls.Add(_chkPhrases);
            _toolbar.Controls.Add(_regionSeg);
            _toolbar.Controls.Add(_seg);

            // ---- content: two cards ------------------------------------
            TableLayoutPanel table = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                BackColor = Theme.Background,
                ColumnCount = 2,
                RowCount = 1
            };
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50f));
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50f));
            table.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));

            // left card: 原文
            RoundedCard cardLeft = new RoundedCard { Dock = DockStyle.Fill, Margin = new Padding(16, 16, 6, 16) };
            Panel bodyLeft = new Panel { Dock = DockStyle.Fill, BackColor = Theme.White, Padding = new Padding(10) };
            _txtInput = new AutoScrollTextBox
            {
                Multiline = true,
                Dock = DockStyle.Fill,
                WordWrap = true,
                ScrollBars = ScrollBars.Vertical,
                AcceptsReturn = true,
                AcceptsTab = false,
                BorderStyle = BorderStyle.None,
                BackColor = Theme.White,
                ForeColor = Theme.TextPrimary,
                Font = Theme.Body,
                TabIndex = 0,
                AccessibleName = "原文输入"
            };
            _lblPlaceholder = new Label
            {
                Text = "在此输入或粘贴简体中文…",
                AutoSize = true,
                Font = Theme.Body,
                ForeColor = Theme.TextMuted,
                BackColor = Theme.White,
                Location = new Point(12, 12),
                Cursor = Cursors.IBeam
            };
            _lblPlaceholder.Click += delegate { _txtInput.Focus(); };
            bodyLeft.Controls.Add(_txtInput);
            bodyLeft.Controls.Add(_lblPlaceholder);
            _lblPlaceholder.BringToFront();

            _headLeft = BuildCardHeader("原文", out _lblInputTitle, out _lblInputCount, out _btnPaste);
            _btnPaste.Click += delegate { PasteFromClipboard(); };
            cardLeft.Controls.Add(bodyLeft);
            cardLeft.Controls.Add(_headLeft);

            // right card: 结果
            RoundedCard cardRight = new RoundedCard { Dock = DockStyle.Fill, Margin = new Padding(6, 16, 16, 16) };
            Panel bodyRight = new Panel { Dock = DockStyle.Fill, BackColor = Theme.White, Padding = new Padding(10) };
            _txtOutput = new AutoScrollTextBox
            {
                Multiline = true,
                Dock = DockStyle.Fill,
                WordWrap = true,
                ScrollBars = ScrollBars.Vertical,
                AcceptsReturn = true,
                AcceptsTab = false,
                BorderStyle = BorderStyle.None,
                BackColor = Theme.White,
                ForeColor = Theme.TextPrimary,
                Font = Theme.Body,
                TabIndex = 5,
                AccessibleName = "结果输出"
            };
            bodyRight.Controls.Add(_txtOutput);

            _headRight = BuildCardHeader("结果", out _lblOutputTitle, out _lblOutputCount, out _btnCopy);
            _btnCopy.Click += delegate { CopyResult(); };
            cardRight.Controls.Add(bodyRight);
            cardRight.Controls.Add(_headRight);

            table.Controls.Add(cardLeft, 0, 0);
            table.Controls.Add(cardRight, 1, 0);

            // ---- status strip -------------------------------------------
            _status = new Panel { Dock = DockStyle.Bottom, Height = 30, BackColor = Theme.Background };
            _lblStatus = new Label
            {
                Text = "就绪",
                AutoSize = true,
                Font = Theme.Subtitle,
                ForeColor = Theme.TextSecondary,
                Location = new Point(20, 8),
                BackColor = Color.Transparent
            };
            _lblEngine = new Label
            {
                Text = "OpenCC · 离线",
                AutoSize = true,
                Font = Theme.Subtitle,
                ForeColor = Theme.TextMuted,
                BackColor = Color.Transparent,
                Anchor = AnchorStyles.Top | AnchorStyles.Right
            };
            _status.Controls.Add(_lblEngine);
            _status.Controls.Add(_lblStatus);

            // Dock order: last added is docked first.
            Controls.Add(table);
            Controls.Add(_status);
            Controls.Add(_toolbar);
            Controls.Add(_header);

            // events
            _txtInput.TextChanged += delegate
            {
                _lblInputCount.Text = _txtInput.Text.Length + " 字";
                _lblPlaceholder.Visible = _txtInput.Text.Length == 0;
                _debounce.Stop();
                _debounce.Start();
            };
            _txtOutput.TextChanged += delegate
            {
                _lblOutputCount.Text = _txtOutput.Text.Length + " 字";
            };

            Shown += OnShown;
            _header.Resize += delegate { LayoutHeader(); };
        }

        private Panel BuildCardHeader(string title, out Label titleLabel, out Label counter, out LinkButton action)
        {
            Panel head = new Panel { Dock = DockStyle.Top, Height = 40, BackColor = Theme.White };
            Label lbl = new Label
            {
                Text = title,
                AutoSize = true,
                Font = Theme.CardHeader,
                ForeColor = Theme.TextPrimary,
                Location = new Point(16, 9),
                BackColor = Color.Transparent
            };
            titleLabel = lbl;
            counter = new Label
            {
                Text = "0 字",
                AutoSize = true,
                Font = Theme.Counter,
                ForeColor = Theme.TextMuted,
                BackColor = Color.Transparent,
                Location = new Point(70, 14)
            };
            action = new LinkButton { Text = title == "原文" ? "粘贴" : "复制", TabIndex = title == "原文" ? 2 : 3 };
            action.AccessibleName = action.Text;
            action.SizeToText();
            action.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            action.Location = new Point(head.Width - 16 - action.Width, 7);
            head.Controls.Add(counter);
            head.Controls.Add(action);
            head.Controls.Add(lbl);
            return head;
        }

        private void OnShown(object sender, EventArgs e)
        {
            try
            {
                Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
            catch
            {
                // icon is optional
            }
            _seg.Left = 20;
            _seg.Top = (_toolbar.Height - _seg.Height) / 2;
            _regionSeg.Left = _seg.Right + 24;
            _regionSeg.Top = (_toolbar.Height - _regionSeg.Height) / 2;
            _chkPhrases.Left = _regionSeg.Right + 24;
            _chkPhrases.Top = (_toolbar.Height - _chkPhrases.Height) / 2;
            LayoutHeader();
            LayoutCardHeader(_headLeft, _lblInputTitle, _lblInputCount, _btnPaste);
            LayoutCardHeader(_headRight, _lblOutputTitle, _lblOutputCount, _btnCopy);
            _lblEngine.Left = _status.Width - 20 - _lblEngine.Width;
            UpdatePhrasesEnabled();
            _txtInput.Focus();
        }

        private static void LayoutCardHeader(Panel head, Label title, Label counter, LinkButton action)
        {
            counter.Left = title.Right + 8;
            action.Left = head.Width - 16 - action.Width;
        }

        // ---- behavior ---------------------------------------------------

        private void OnDebounceTick(object sender, EventArgs e)
        {
            _debounce.Stop();
            StartConversion();
        }

        private void OnDirectionChanged(object sender, EventArgs e)
        {
            _s2t = _seg.SelectedIndex == 0;
            _lblPlaceholder.Text = _s2t ? "在此输入或粘贴简体中文…" : "在此输入或粘贴繁体中文…";
            Reconvert();
        }

        private void OnVariantChanged(object sender, EventArgs e)
        {
            _variant = (ChineseVariant)_regionSeg.SelectedIndex;
            UpdatePhrasesEnabled();
            Reconvert();
        }

        private void OnPhrasesChanged(object sender, EventArgs e)
        {
            _localPhrases = _chkPhrases.Checked;
            Reconvert();
        }

        private void OnPinToggled(object sender, EventArgs e)
        {
            _btnPin.Checked = !_btnPin.Checked;
            TopMost = _btnPin.Checked;
        }

        private void UpdatePhrasesEnabled()
        {
            _chkPhrases.Enabled = _variant != ChineseVariant.Standard;
        }

        private void LayoutHeader()
        {
            if (_btnClear == null || _btnPin == null) return;
            int right = _header.Width - 20;
            _btnClear.Left = right - _btnClear.Width;
            _btnClear.Top = (_header.Height - _btnClear.Height) / 2;
            _btnPin.Left = _btnClear.Left - 8 - _btnPin.Width;
            _btnPin.Top = (_header.Height - _btnPin.Height) / 2;
        }

        private void Reconvert()
        {
            _debounce.Stop();
            StartConversion();
        }

        private static string ProfileName(bool s2t, ChineseVariant variant, bool phrases)
        {
            string direction = s2t ? "简→繁" : "繁→简";
            string region;
            switch (variant)
            {
                case ChineseVariant.Taiwan: region = "台湾"; break;
                case ChineseVariant.HongKong: region = "香港"; break;
                default: region = "标准"; break;
            }
            if (variant != ChineseVariant.Standard && phrases) region += "·用词";
            return direction + " " + region;
        }

        private void StartConversion()
        {
            string input = _txtInput.Text;
            if (input.Length == 0)
            {
                _version++;
                if (_txtOutput.Text.Length != 0) _txtOutput.Text = string.Empty;
                _lblStatus.Text = "就绪";
                return;
            }
            int ver = ++_version;
            bool s2t = _s2t;
            ChineseVariant variant = _variant;
            bool phrases = _localPhrases;
            Stopwatch sw = Stopwatch.StartNew();
            Task.Factory.StartNew(delegate
            {
                string result = null;
                Exception error = null;
                try
                {
                    result = OpenCCEngine.Convert(input, s2t, variant, phrases);
                }
                catch (Exception ex)
                {
                    error = ex;
                }
                sw.Stop();
                long ms = sw.ElapsedMilliseconds;
                try
                {
                    BeginInvoke((MethodInvoker)delegate
                    {
                        if (ver != _version) return; // stale result
                        if (error != null)
                        {
                            _lblStatus.Text = "转换失败：" + error.Message;
                            return;
                        }
                        _txtOutput.Text = result;
                        _lblStatus.Text = "已转换 · " + ms + " ms · " + ProfileName(s2t, variant, phrases);
                    });
                }
                catch (ObjectDisposedException)
                {
                    // form is closing
                }
                catch (InvalidOperationException)
                {
                    // handle no longer valid
                }
            });
        }

        private void PasteFromClipboard()
        {
            if (!Clipboard.ContainsText())
            {
                _lblStatus.Text = "剪贴板中没有文本";
                return;
            }
            _txtInput.Text = Clipboard.GetText();
            _debounce.Stop();
            StartConversion();
        }

        private void CopyResult()
        {
            if (_txtOutput.Text.Length == 0) return;
            Clipboard.SetText(_txtOutput.Text);
            _lblStatus.Text = "已复制到剪贴板";
        }

        private void ClearAll()
        {
            _version++;
            _debounce.Stop();
            _txtInput.Text = string.Empty;
            _txtOutput.Text = string.Empty;
            _lblInputCount.Text = "0 字";
            _lblOutputCount.Text = "0 字";
            _lblStatus.Text = "就绪";
            _txtInput.Focus();
        }
    }
}
