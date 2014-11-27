extends SceneTree

static func post(host,port,path,msg,cb,isRaw = false):
	var err=0
	var http = HTTPClient.new()
	var err = http.connect(host,port)
	msg = msg.to_json()
	var f = FuncRef.new()
	f.set_instance(cb.instance)
	f.set_function(cb.f)
	assert(err==OK)
	while( http.get_status()==HTTPClient.STATUS_CONNECTING or http.get_status()==HTTPClient.STATUS_RESOLVING):
		http.poll()
		print("Connecting..")
		OS.delay_msec(500)
	assert( http.get_status() == HTTPClient.STATUS_CONNECTED )

	var headers=[
	"User-Agent: Pirulo/1.0 (Godot)",
	"Accept: */*",
	"Content-Type:application/x-www-form-urlencoded"
	]

	err = http.request(HTTPClient.METHOD_POST,path,headers)
	assert( err == OK )
	
	while (http.get_status() == HTTPClient.STATUS_REQUESTING):
		# Keep polling until the request is going on
		http.poll()
		print("Requesting..")
		OS.delay_msec(500)

	assert( http.get_status() == HTTPClient.STATUS_BODY or http.get_status() == HTTPClient.STATUS_CONNECTED ) # Make sure request finished well.
	
	print("response? ",http.has_response()) # Site might not have a response.
	
	
	if (http.has_response()):
		var headers = http.get_response_headers_as_dictionary() # Get response headers
		print("code: ",http.get_response_code()) # Show response code
		print("**headers:\n",headers) # Show headers
		if (http.is_response_chunked()):
			#Does it use chunks?
			print("Respose is Chunked!")
		else:
			#Or just plain Content-Length
			var bl = http.get_response_body_length()
			print("Response Length: ",bl)
		
		var rb = RawArray() #array that will hold the data

		while(http.get_status()==HTTPClient.STATUS_BODY):
			#While there is body left to be read
			http.poll()
			var chunk = http.read_response_body_chunk() # Get a chunk
			if (chunk.size()==0):
				#got nothing, wait for buffers to fill a bit
				OS.delay_usec(1000)
			else:
				rb = rb + chunk # append to read bufer
		if isRaw:
			f.call_func(rb)
		else:
			f.call_func(rb.get_string_from_ascii())
