using System;
using System.Runtime.InteropServices;
using System.Text;
using Godot;

// Asks Windows for the player's account picture. Windows writes a readable
// copy to %TEMP%\<user>.bmp and hands back its path. PlayerIdentity calls this
// because GDScript can't reach Windows functions, and the real picture folders
// are admin-only.
public partial class WindowsUserPicture : RefCounted
{
	// shell32's unnamed export #261, the user-tile call the old control panel uses.
	[DllImport("shell32.dll", EntryPoint = "#261", CharSet = CharSet.Unicode, PreserveSig = false)]
	private static extern void GetUserTilePath(string username, uint flags, StringBuilder path, int length);

	public string TilePath()
	{
		if (!OperatingSystem.IsWindows())
			return "";
		try
		{
			var path = new StringBuilder(1024);
			GetUserTilePath(null, 0x80000000, path, path.Capacity);
			return path.ToString();
		}
		catch (Exception e)
		{
			GD.PushWarning("WindowsUserPicture: Windows gave no picture (" + e.Message + ")");
			return "";
		}
	}
}
