"""Tests the real Linux serial path against a pseudo-terminal, never a robot."""
import base64,json,os,pty,socket,subprocess,sys,tempfile
master,slave=pty.openpty()
server=socket.socket(); server.bind(('127.0.0.1',0)); server.listen(); server.settimeout(5)
process=subprocess.Popen([sys.executable,sys.argv[1],'--port',os.ttyname(slave),'--socket',str(server.getsockname()[1]),'--token','test-only'])
try:
    app,_=server.accept(); app.settimeout(5); reader=app.makefile('rb')
    assert json.loads(reader.readline())=={'token':'test-only'}
    assert json.loads(reader.readline())=={'connected':True}
    payload=bytes(range(256))
    os.write(master,payload)
    result=b''
    while len(result)<len(payload): result+=base64.b64decode(json.loads(reader.readline())['bytes'])
    assert result==payload,'serial receive corrupt'
    app.sendall((json.dumps({'bytes':base64.b64encode(payload).decode()})+'\n').encode())
    import select
    result=b''
    while len(result)<len(payload):
        assert select.select([master],[],[],5)[0],'serial write timeout'
        result+=os.read(master,4096)
    assert result==payload,'serial transmit corrupt'
    app.sendall(b'{"close":true}\n')
    process.wait(timeout=5)
    print('Linux PTY serial: PASS (all 256 bytes, both directions, clean close)')
finally:
    if process.poll() is None: process.terminate(); process.wait(timeout=5)
    os.close(master); os.close(slave); server.close()
