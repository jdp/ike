#!/usr/bin/env io

Ike := Object clone do(
	tasks        := list()
	logging      := true
	nextDesc     := nil
	nsParts      := list()
	dependencies := list()
	successes    := list()
)

Ike Task := Object clone do(

	with := method(name, body, desc, deps,
		self setSlot("result", true)
		self setSlot("name", name) 
		self setSlot("body", body) 
		self setSlot("desc", desc)
		self setSlot("deps", deps)
		self
	)

	invoke := method(
		e := try(result := doMessage(body))
		e catch(fail(e error))
		if(result not, fail)
	)
		
	fail := method(
		write("=> Task `", name, "' failed")
		if(call argCount > 0, write(": ", call evalArgs join))
		write("\n")
		System exit(1)
	)
	
	sh := method(command,
		cmd := System runCommand(command)
		if(cmd exitStatus > 0, fail(cmd stderr))
		cmd
	)
	
)

Ike do(

	task := method(name,
		name = list(nsParts, name) flatten join(":")
		tasks << Ike Task clone with(name, call message arguments last, nextDesc, dependencies)
		nextDesc = nil
		dependencies = list()
	)

	desc := method(description,
		nextDesc = description  
	)		

	namespace := method(space,
		nsParts << space
		call message argAt(1) doInContext(Ike)
		nsParts removeLast
	)
	
	depends := method(
		call evalArgs foreach(dep, dependencies << dep)
	)

	invoke := method(target,
		task := tasks detect(name == target)
		if(task isNil,
			return taskNotFound(target)
		,
			task deps difference(Ike successes) foreach(dep,
				log("Invoking dependency `", dep, "'")
				tasks detect(name == dep) ?invoke
			)
			log("Invoking `", target, "'")
			task ?invoke
			Ike successes << task name
		)
	)
	
	taskNotFound := method(target,
		writeln("=> Task `", target, "' isn't defined")
		false
	)

	log := method(
		if(logging, writeln("=> ", call evalArgs join))
	)
	
)

// Create a list append operator <<
List << := method(other, append(other))

// Transfer each of these calls from lobby to Ike object
list("task", "desc", "namespace", "depends") foreach(slot,
	setSlot(slot, method(call delegateTo(Ike)))
)

// Add some default tasks to simulate command-line options
task("-h", """ike [tasks]

Built-in tasks:
  -h  Show this summary
  -T  Show described tasks
  -V  Show Ike version""" println
)

task("-V", "ike, version 0.1.0" println)

task("-T",
	describedTasks := Ike tasks select(desc isNil not)
	longest := describedTasks map(name size) max
	describedTasks foreach(task,
		write("ike ", task name)
		diff := longest - task name size
      	writeln(" " repeated(diff), " # ", task desc)
	)  
	true
)

list("Ikefile", "ikefile", "Ikefile.io", "ikefile.io") foreach(ikefile,
	if(File exists(ikefile), doFile(ikefile); break)
)

options := System args
options removeFirst
if(options isEmpty, options << "default")
options foreach(option, Ike invoke(option))

