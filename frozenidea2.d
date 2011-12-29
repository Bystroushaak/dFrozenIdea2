/**
 * FrozenIdea2
 * 
 * Simple event driven IRC bot.
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.4.1
 * Date:    29.12.2011
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
*/
module frozenidea2;

import std.socket;
import std.algorithm : remove;
import std.string;
import std.algorithm : countUntil;


const string ENDL = "\r\n";


private struct Msg{
	string from;
	string type;
	string msg;
}


/// Throw this for quit
class QuitException : Exception{
	this(string msg){
		super(msg);
	}
}


///
class IRCbot {
	protected string nickname;
	protected TcpSocket connection;
	
	protected string[][string] channels;
	
	///
	public string real_name;
	/// Server password
	public string password;
	
	/// Set name.
	this(string nickname){
		this.nickname = nickname;
		this.real_name = "FrozenIdea IRC bot";
	}
	
	/// Set name and connect to the server.
	this(string nickname, string server, ushort port = 6667){
		this(nickname);
		this.connect(server, port);
	}
	
	/// Connect bot to the server. Call IRCbot.run() after this. 
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
	
	/// Join bot to the chan (have to begin with '#').
	public final void join(string chan){
		this.socketSendLine("JOIN " ~ chan);
	}
	
	/**
	 * Send message to the channel. 
	 * 
	 * Throws: Exception, when not joined.
	*/ 
	public final void sendMsg(string chan, string msg){
		if (chan !in this.channels)
			throw new Exception("I'am not joined in " ~ chan ~ "!");
		
		this.sendPrivateMsg(chan, msg);
	}
	
	/// Send private message to the user.
	public final void sendPrivateMsg(string to, string msg){
		this.socketSendLine("PRIVMSG " ~ to ~ " :" ~ msg);
	}
	
	/// Leave chan, which have to begin with '#'.
	public void part(string chan){
		this.socketSendLine("PART " ~ chan);
	}
	
	///
	public void quit(){
		foreach(key, val; this.channels){
			this.part(key);
		}
		
		throw new QuitException("Quit");
	}
	
	/**
	 * Main method of the class. 
	*/ 
	public void run(){
		SocketSet chk = new SocketSet();
		
		int read;
		char buff[1024];
		
		int io_endl;
		string msg;
		string msg_queue;
		
		// send user information
		if (this.password != "")
			this.socketSendLine("PASS " ~ this.password);
		
		this.socketSendLine("USER " ~ this.nickname ~ " 0 0 :" ~ this.real_name);
		this.socketSendLine("NICK " ~ this.nickname);
		
		// connection loop
		for (;;chk.reset()){
			chk.add(this.connection);
			
			Socket.select(chk, null, null);
			
			read = this.connection.receive(buff);
			
			if (read != 0 && read != Socket.ERROR){
				msg_queue ~= cast(string) buff[0 .. read];
				
				// handle messages in queue
				while ((io_endl = msg_queue.indexOf(ENDL)) > 0){
					msg = msg_queue[0 .. io_endl + ENDL.length];
					
					// ping handling
					if (msg.startsWith("PING"))
						this.socketSendLine("PONG " ~ msg.split()[1].strip());
					else{
						try{
							this.logic(parseMsg(msg));
						}catch(QuitException e){
							this.connection.close();
							this.onConnectionClose();
							
							return;
						}
					}
					
					// remove message from queue
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
	
	/// Parse message from string into structure Msg
	protected final Msg parseMsg(string line){
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
	
	// http://www.irchelp.org/irchelp/rfc/chapter6.html#c6_2
	protected void logic(Msg m){
		if (m.type.startsWith("376")){ // end of motd
			this.onServerConnected();
			
		}else if (m.type.startsWith("353")){ // nick list
			string chan_name = m.type[m.type.indexOf("#") .. $];
			
			// check if chan is in chanlist
			bool new_chan = false;
			if (chan_name !in this.channels)
				new_chan = true;
			
			this.channels.remove(chan_name);
			foreach(nick; m.msg.split())
				this.channels[chan_name] ~= nick;
			
			if (new_chan)
				onChannelJoin(chan_name);
				
		}else if (m.type.startsWith("PRIVMSG")){ // msg
			if (m.type.indexOf("#") > 0)
				this.onChannelMessage(m.type.split()[$-1], m.from, m.msg);
			else
				this.onPrivateMessage(m.type.split()[$-1], m.msg);
				
		}else if (m.type.startsWith("404")){  // kicked from chan
			this.channels.remove(m.type.split()[$-1]);
			
		}else if (m.type.startsWith("JOIN")){ // join msg
			string nick = m.from[0 .. m.from.indexOf("!")];
			string chan_name = m.msg;
			
			// okay, ugly
			if (nick != this.nickname){
				int nick_index = 0;
				bool found = false;
				foreach(n; this.channels[m.msg]){ // add only nick thet aren't added yet
					if (n == nick){
						found = true;
						break;
					}
					nick_index++;
				}
				
				if (!found)
					this.channels[m.msg] ~= nick;
				
				this.onSomebodyJoinedChan(m.msg, nick);
			}
		}else if (m.type == "NICK"){ // rename message
			string old_nick = m.from[0 .. m.from.indexOf("!")];
			
			int io;
			foreach(chan, val; this.channels){
				if ((io = channels[chan].countUntil(old_nick)) >= 0)
					channels[chan][io] = m.msg;
			}
			
		}else if (m.type.startsWith("PART")){ // part message
			string chan = m.type.split()[$-1];
			string nick = m.from[0 .. m.from.indexOf("!")];
			
			if (nick != this.nickname){
				int nick_index = 0;
				bool found = false;
				foreach(n; this.channels[chan]){
					if (n == nick){
						found = true;
						break;
					}
					nick_index++;
				}
				
				if (found) // remove nick from chanlist array
					this.channels[chan] = this.channels[chan].remove(nick_index);
				
				this.onSomebodyLeavedChan(chan, nick);
			}
			
		}else if (m.type.startsWith("QUIT")){ // quit message
			string quit_nick =  m.from[0 .. m.from.indexOf("!")];
			
			// remove nick from all chans
			int index = 0;
			foreach(chan, nicks; this.channels){
				index = 0;
				foreach(nick; nicks){
					if (nick == quit_nick){
						this.channels[chan] = this.channels[chan].remove(index);
						this.onSomebodyLeavedChan(chan, quit_nick);
						break;
					}
					index++;
				}
			}
			
			this.onSomebodyQuit(quit_nick);
		}
	}
	
	/// Called when connected and logged to the server.
	public void onServerConnected(){
	}
	/// Called when disconnected from server.
	public void onConnectionClose(){
	}
	/**
	 * Called when joined to the channel.
	 * 
	 * Look at this.channels[chan] = [nick, array];
	*/
	public void onChannelJoin(string chan){
	}
	/// Called if anyone post something into chan.
	public void onChannelMessage(string chan, string from, string message){
	}
	/// Called when privmsg received.
	public void onPrivateMessage(string from, string message){
	}
	/// Called when somebody join to the chan.
	public void onSomebodyJoinedChan(string chan, string who){
	}
	/// Called when somebody leaves channel.
	public void onSomebodyLeavedChan(string chan, string who){
	}
	/// Called when somebody quit.
	public void onSomebodyQuit(string who){
	}
}
