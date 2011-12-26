/**
 * Picak - small anoying IRCbot targeted to user povik.
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.2.0
 * Date:    25.12.2011
 * URL:     http://kitakitsune.org/raw/picak.zip
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
*/
import std.stdio;
import std.getopt;
import std.algorithm;
import std.random;
import std.datetime;

import frozenidea2;



const string HELP_STR    = import("help.txt");
const string VERSION_STR = import("version.txt");



class QuitException : Exception{
	this(string msg){
		super(msg);
	}
}



class Picak : IRCbot{
	private string[] hlasky;
	private SysTime last_time;
	
	this(string nick, string server){
		super(nick, server);
		
		hlasky ~= "pises, pises?!!!!!!!!!";
		hlasky ~= "uz jsi algoritmicky vytlacil ten clanek?!!!!!!!!";
		hlasky ~= "tak co, uz to bude?!!!!";
		hlasky ~= "tak kde je ten clanek, dammit?!!!!!!";
		hlasky ~= "no, uz to bude?!!!!!!!!!!";
		hlasky ~= "jak dlouho nas jeste nechas cekat?!!!!!!!";
		
		this.real_name = "Picak v2";
	}
	void onServerConnected(){
		join("#shadowfall");
	}
	
	void onChannelJoin(string chan){
		picuj(chan);
	}
	
	void onChannelMessage(string chan, string from, string message){
		picuj(chan);
	}
	
	void onSomebodyJoinedChan(string chan, string who){
		picuj(chan);
	}
	
	void picuj(string chan){
		if (this.channels[chan].count("povik") > 0 && last_time + dur!("minutes")(30) < Clock.currTime()){
			sendMsg(chan, "povik: " ~ hlasky[uniform(0, hlasky.length)]);
			this.last_time = Clock.currTime();
		}
	}
}


int main(string[] args){
	// parameters for options parsing
	bool help, ver;
	
	// parse options
	try{
		getopt(
			args,
			std.getopt.config.bundling, // onechar shortcuts
			"help|h", &help,
			"version|v", &ver
		);
	}catch(Exception e){
		stderr.writeln(HELP_STR);
		return 1;
	}
	if (help){
		writeln(HELP_STR);
		return 0;
	}
	if (ver){
		writeln(VERSION_STR);
		return 0;
	}
	
	
	
	// here goes program
	Picak p = new Picak("picak_mk2", "monka.hysteria.cz");
	
	try{
		p.run();
	}catch(QuitException e){
	}
	
	
	return 0;
}
