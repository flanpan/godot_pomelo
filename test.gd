extends Panel
export(String) var host = "127.0.0.1"

export(int) var port = 10001

var pomelo
var httpClient 

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
	var b = Marshalls.variant_to_base64('aaa')
	print(b)
	print(Marshalls.base64_to_variant(b))
	
	pomelo = get_node("/root/global").pomelo
	httpClient = get_node("/root/global").httpClient
	
	pomelo.init(host,port)
	pomelo.on("error",self,"_on_errror")
	#print(pomelo._connect(host,port))
	#print(pomelo.socket.is_connected())
	var root = get_tree().get_root()
	pass

func _on_Button_1_pressed():
	set_text(get_text()+"a")
	#pomelo._send("1")
	pomelo.request("connector.entryHandler.entry",{
	
	token='a67a3ef88faef78184c049785453908fd51732f85276b9d11f71fcf46b276a4e446124d175561f7ddcdfa25e5e3a1f65'
	
	},self,"_on_query_entry")
	

func _on_query_entry(msg):
	print(msg)
	set_text(msg.to_json())
	pomelo.request('game.gameHandler.entryGame',{roleName='robot1'},self,'_onstart')
	
func _on_errror(msg):
	print(msg)
	
func _onstart(msg):
	var cfg = ConfigFile.new()
	cfg.load('res://user_config.cfg')
	cfg.set_value("pomelo","aaa",msg.to_json())
	cfg.save('res://aaa')
	print('onentrygame')
	#print(msg.to_json())

func _on_Button_2_pressed():
	httpClient.post('192.168.3.56',3001,'/login',{},{instance=self,f='_button2rep'})
	
func _button2rep(data):
	#get_node('Button2').set_text(data)
	print(data)