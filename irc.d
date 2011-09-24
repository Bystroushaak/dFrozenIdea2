/**
 * 
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.0.1
 * Date:    
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
*/
import std.stdio;

import std.socket;
import std.algorithm : remove;
//~ import std.array;
import std.string;


const string ENDL = "\r\n";


private struct Msg{
	string from;
	string type;
	string msg;
}


class IRCbot {
	protected string nickname;
	protected TcpSocket connection;
	
	public string real_name;
	public string password;
	
	this(string nickname){
		this.nickname = nickname;
		this.real_name = "FrozenIdea IRC bot";
	}
	
	this(string nickname, string server, ushort port = 6667){
		this(nickname);
		this.connect(server, port);
	}
	
	public void connect(string server, ushort port = 6667){
		this.connection = new TcpSocket(AddressFamily.INET);
		this.connection.connect(new InternetAddress(server, port));
		this.connection.blocking = false;
	}
	
	/**
	 * Wrapper over socket.send(). Every message closed with ENDL.
	 * 
	 * DO NOT use if you aren't sure why.
	*/ 
	public final void socketSendLine(string msg){
		this.connection.send(msg ~ ENDL);
	}
	
	public final join(string chan){
	}
	
	public void run(){
		SocketSet chk = new SocketSet();
		
		char buff[1024];;
		int read;
		string msg_queue, msg;
		int io_endl;
		
		for (;;chk.reset()){
			chk.add(this.connection);
			
			Socket.select(chk, null, null);
			
			read = this.connection.receive(buff);
			
			if (read != 0 && read != Socket.ERROR){
				msg_queue ~= cast(string) buff[0 .. read];
				
				while ((io_endl = msg_queue.indexOf(ENDL)) > 0){
					msg = msg_queue[0 .. io_endl + ENDL.length];
					
					if (msg.startsWith("PING"))
						this.socketSendLine("PONG " ~ msg.split()[1].strip());
					else{
						this.logic(parseMsg(msg));
					}
					
					if (msg.length <= msg_queue.length - 1)
						msg_queue = msg_queue[msg.length .. $];
					else
						msg_queue = "";
					
				}
				
				buff.clear();
			}else{
				this.connection.close();
				this.onConnectionClose();
				break;
			}
		}
	}
	
	private final Msg parseMsg(string line){
		Msg m;
		
		line = line[1 .. $]; // remove : from msg
		
		if (line.indexOf(":") > 0)
			m.msg = line[line.indexOf(":") + 1 .. $].stripRight();
		else
			m.msg = "";
		
		m.from = line[0 .. line.indexOf(" ")].stripRight();
		
		if (line.indexOf(":") > 0)
			m.type = line[line.indexOf(" ") + 1 .. line.indexOf(":")].stripRight();
		else
			m.type = line[line.indexOf(" ") + 1 .. $].stripRight();
		
		return m;
	}
	
	private void logic(Msg m){
		if (m.type == "NOTICE AUTH" && m.msg == "*** No Ident response"){
			if (this.password != "")
				this.socketSendLine("PASS " ~ this.password);
			
			this.socketSendLine("USER " ~ this.nickname ~ " 0 0 :" ~ this.real_name);
			this.socketSendLine("NICK " ~ this.nickname);
			
			this.onServerConnection();
		}
		else if (m.type.startsWith("376")) // end of motd
			this.onConnectedToServer();
	}
	
	public void onServerConnection(){
	}
	public void onConnectedToServer(){
	}
	public void onConnectionClose(){
	}
}


int main(string[] args){
	IRCbot b = new IRCbot("FrozenIdea2", "irc.2600.net", 6667);
	b.run();
	
	return 0;
}