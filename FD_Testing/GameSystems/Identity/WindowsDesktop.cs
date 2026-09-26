using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using Godot;
using Microsoft.Win32;

// What PlayerIdentity needs from Windows for the wallpaper, asked in-process so
// the game never starts a command line: the monitors plugged in right now
// (Wallpaper Engine files its wallpapers under them), Wallpaper Engine itself, and Steam.
public partial class WindowsDesktop : RefCounted
{
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	private struct DisplayDevice
	{
		public int cb;
		[MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
		[MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
		public int StateFlags;
		[MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
		[MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
	}

	[DllImport("user32.dll", CharSet = CharSet.Unicode)]
	private static extern bool EnumDisplayDevicesW(string device, uint index, ref DisplayDevice info, uint flags);

	private const int AttachedToDesktop = 0x1;
	private const int PrimaryDevice = 0x4;
	private const int MonitorActive = 0x1;
	private const uint GetDeviceInterfaceName = 0x1;

	// Device paths of the monitors showing the desktop, the main one first:
	// \\?\DISPLAY#HWV62F5#5&2676641d&0&UID4353#{e6f07b5f-...}
	public string[] ActiveMonitors()
	{
		var main = new List<string>();
		var others = new List<string>();
		if (!OperatingSystem.IsWindows())
			return main.ToArray();
		try
		{
			for (uint s = 0; s < 64; s++)
			{
				var source = new DisplayDevice { cb = Marshal.SizeOf<DisplayDevice>() };
				if (!EnumDisplayDevicesW(null, s, ref source, 0))
					break;
				if ((source.StateFlags & AttachedToDesktop) == 0)
					continue;
				var into = (source.StateFlags & PrimaryDevice) != 0 ? main : others;
				for (uint m = 0; m < 16; m++)
				{
					var monitor = new DisplayDevice { cb = Marshal.SizeOf<DisplayDevice>() };
					if (!EnumDisplayDevicesW(source.DeviceName, m, ref monitor, GetDeviceInterfaceName))
						break;
					if ((monitor.StateFlags & MonitorActive) != 0 && !string.IsNullOrEmpty(monitor.DeviceID))
						into.Add(monitor.DeviceID);
				}
			}
		}
		catch (Exception e)
		{
			GD.PushWarning("WindowsDesktop: couldn't list the monitors (" + e.Message + ")");
		}
		main.AddRange(others);
		return main.ToArray();
	}

	// The running Wallpaper Engine's exe: its full path when Windows lets us
	// read it, just its name when not, "" when it isn't running.
	public string WallpaperEngine()
	{
		foreach (var name in new[] { "wallpaper64", "wallpaper32" })
		{
			Process[] found;
			try
			{
				found = Process.GetProcessesByName(name);
			}
			catch (Exception)
			{
				continue;
			}
			if (found.Length == 0)
				continue;
			var path = name + ".exe";
			try
			{
				path = found[0].MainModule?.FileName ?? path;
			}
			catch (Exception)
			{
				// running as admin, or 64-bit peeking at 32-bit: the name is enough
			}
			foreach (var p in found)
				p.Dispose();
			return path;
		}
		return "";
	}

	// Steam's own folder from the registry, "" if Steam isn't installed.
	public string SteamPath()
	{
		if (!OperatingSystem.IsWindows())
			return "";
		try
		{
			using var key = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam");
			return key?.GetValue("SteamPath") as string ?? "";
		}
		catch (Exception)
		{
			return "";
		}
	}
}
