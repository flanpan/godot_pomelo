extends Button
export(String) var host = "127.0.0.1"

export(int) var port = 11901

var pomelo

func test_utf8():
	var raw = RawArray()
	raw.push_back(0xe5)
	raw.push_back(0x93)
	raw.push_back(0x88)
	var s1 = raw.get_string_from_utf8()
	var s2 = raw.get_string_from_ascii()
	print(s1.ord_at(0))
	print(typeof(s1),typeof(s2))
	
func test_ref_1(t):
	print(t.has("a"))
	t.a = 1
	print(t.a)

class T1:
	var a = 0
	func _init():
		print("init t1")
		
class T2 extends T1:
	func _init():
		pass

func test_ref():
	#var t = T1.new()
	#test_ref_1(t)
	#print(t.a)
	var tt = {}
	test_ref_1(tt)
	print(tt.a)

func _ready():
	test_ref()
	pomelo = get_node("/root/global").pomelo
	print(pomelo,host,port)

	pomelo.init(host,port)
	pomelo.on("error",self,"_on_errror")
	#print(pomelo._connect(host,port))
	#print(pomelo.socket.is_connected())
	var root = get_scene().get_root()
	pass

func _on_Button_pressed():
	set_text(get_text()+"a")
	#pomelo._send("1")
	pomelo.request("gate.gateHandler.queryEntry",{},self,"_on_query_entry")
	

func _on_query_entry(msg):
	print(msg)
	set_text(msg.to_json())
	
func _on_errror(msg):
	print(msg)
