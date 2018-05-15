using System.Net;

public class AutomateLog {
	public string __CURSOR { get; set; }
	public string __REALTIME_TIMESTAMP { get; set; }
	public string __MONOTONIC_TIMESTAMP { get; set; }
	public string _BOOT_ID { get; set; }
	public string _TRANSPORT { get; set; }
	public string PRIORITY { get; set; }
	public string SYSLOG_FACILITY { get; set; }
	public string SYSLOG_IDENTIFIER { get; set; }
	public string _PID { get; set; }
	public string _UID { get; set; }
	public string _GID { get; set; }
	public string _COMM { get; set; }
	public string _EXE { get; set; }
	public string _CMDLINE { get; set; }
	public string _CAP_EFFECTIVE { get; set; }
	public string _SYSTEMD_CGROUP { get; set; }
	public string _SYSTEMD_UNIT { get; set; }
	public string _SYSTEMD_SLICE { get; set; }
	public string _SYSTEMD_INVOCATION_ID { get; set; }
	public string _MACHINE_ID { get; set; }
	public string _HOSTNAME { get; set; }
    private string _MESSAGE_s;
    public string MESSAGE_s { get{
        return _MESSAGE_s; 
        }
    }
    private byte[] _MESSAGE_b;
	public byte[] MESSAGE { set{
        _MESSAGE_b = value;
        _MESSAGE_s = System.Text.Encoding.UTF8.GetString(value);
        }
    }  
}