extends Button
export(String) var host = "127.0.0.1"
export(int) var port = 10000

var pomelo

func _ready():
	pomelo = get_node("/root/pomelo")
	#print(pomelo)
	#pomelo.init(host,port)
	#pomelo.connect('error',self,'_on_errror')
	#print(pomelo._connect(host,port))
	#print(pomelo.socket.is_connected())
	var a = RawArray()
	a.push_back(97)
	var b = RawArray(a)
	print(b.get_string_from_utf8())
	var aaa = 10
	aaa = abs(aaa) >> 0
	print(aaa)


func _on_Button_pressed():
	set_text(get_text()+"a")
	pomelo._send("1")
	#pomelo.request('gate.gateHandler.queryEntry','aaa',self,'_on_query_entry')
	

func _on_query_entry(msg):
	print(msg)
	
func _on_errror(msg):
	print(msg)
