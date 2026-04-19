"""Ad-hoc perf test: compare Invoke-Sqlcmd vs .NET SqlClient for DB listing."""
import time, sys
sys.path.insert(0, ".")
from winrm_helper import run_ps, SA_PWD

query = ("SELECT name, state_desc, recovery_model_desc FROM sys.databases "
         "WHERE database_id > 4 ORDER BY name")

BT = chr(96)  # backtick
# Use PowerShell single-quoted string so the password's '$' chars aren't interpolated.
pwd_esc = SA_PWD.replace("'", "''")
script = f'''
$cs = 'Server=.;Database=master;User Id=sa;Password={pwd_esc};Encrypt=False;TrustServerCertificate=True;'
$conn = New-Object System.Data.SqlClient.SqlConnection $cs
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = @'
{query}
'@
$r = $cmd.ExecuteReader()
while ($r.Read()) {{
  $vals = for ($i=0; $i -lt $r.FieldCount; $i++) {{ $r.GetValue($i).ToString() }}
  $vals -join "{BT}t"
}}
$conn.Close()
'''

for i in range(2):
    t = time.time()
    out, err, rc = run_ps("AgHost-1A", script)
    print(f"run{i}: {time.time()-t:.2f}s rc={rc} lines={len(out.splitlines())}")
    if i == 0:
        print(out[:400])
        if err.strip():
            print("STDERR:", err[:400])
