////
// ike: io make
Ike := Object clone do(
	tasks    := list()
	nextDesc := nil
	logging  := true
	currentNamespace := nil
	dependencies := list()
	successes := list()
)

Ike do(

	Task := Object clone do(
		with := method(name, body, desc, deps,
			self setSlot("name", name) 
			self setSlot("body", body) 
			self setSlot("desc", desc)
			self setSlot("deps", deps)
			self
		)

		invoke := method(
			result := doMessage(body)
			if(result not, fail)
		)
		
		fail := method(
			write("=> Task `", name, "' failed")
			if(call argCount > 0, write(": ", call evalArgs join))
			write("\n")
			exit
		)
	)


	task := method(name,
		if(currentNamespace, name = "#{currentNamespace}:#{name}" interpolate)
		tasks << Ike Task clone with(name, call message arguments last, nextDesc, dependencies)
		nextDesc = nil
		dependencies = list()
	)

	desc := method(description,
		nextDesc = description  
	)		

	namespace := method(space,
		currentNamespace = space
		call message argAt(1) doInContext(Ike)
		currentNamespace = nil
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
	
	showHelp := method(writeln("Help is on the way, dear."))
	
	showVersion := method(writeln("Ike -50"))

	showTasks := method(
		longest := tasks map(name size) max
		tasks foreach(task,
			// rake style hiding of tasks without descriptions
			if(task desc isNil, continue)
			write("ike ", task name)
			diff := longest - task name size
      		writeln(" " repeated(diff + 7), " # ", task desc)
		)  
	)
	
)

/* Create a list append operator << */
List << := method(other, append(other))

// Transfer each of these calls from lobby to Ike object
list("task", "desc", "namespace", "depends") foreach(slot,
	setSlot(slot, method(call delegateTo(Ike)))
)

list("Ikefile", "ikefile", "Ikefile.io", "ikefile.io") foreach(ikefile,
	if(File exists(ikefile), doFile(ikefile); break)
)

/* Parse arguments into easily workable units */
options := System getOptions(System args slice(1)) map(k, v, list(k, v))
switches := options select(v, v at(0) exSlice(0, 1) == "-" and v at(1) == "") map(at(0))
pairs := options select(at(1) != "") map(v, Map clone atPut(v at(0), v at(1)))
words := options select(at(1) == "") map(at(0)) difference(switches)

/* Do work */
if(switches contains("-h"), Ike showHelp; exit)
if(switches contains("-v"), Ike showVersion; exit)
if(switches contains("-T"), Ike showTasks; exit)

if(words size == 0, 
	Ike invoke("default")
, 
	words foreach(a,
		Ike log("Ike job `", a, "'")
		Ike invoke(a)
	)
)

