class Interpreter{
    constructor(){
        this.program = [];
        this.ip = 0;
        this.stack = [];
        this.call_stack = [];
        this.csp = 0;

        this.stackElem = null;
        this.consoleElem = null;
        this.callStackElem = null;
        this.codeElem = null;

        this.ok = true
    }
    start(){
        const interval = setInterval(()=>{
            this.execute_instruction()
            if(!vm.ok){clearInterval(interval)}
        }, 100)
    }
    execute_instruction(){
        const codeLines = this.codeElem.querySelectorAll("div")
        let old_ip = this.ip
        const operation = this.program[this.ip][0];
        const operand = parseInt(this.program[this.ip][1])
        switch (operation) {
            case "HALT":
                this.ok = false
            case "PUSH":
                this.stack.push(operand)
                break;
            case "JMP":
                this.ip += operand-1
                break;
            case "JNE":
                if(this.stack.pop() != 1){
                    this.ip += operand-1
                }
                break;
            case "CALL":
                this.call_stack[this.csp] = {"ip":this.ip, "vars": new Int32Array(30)}
                this.ip = operand-1
                this.csp += 1
                break;
            case "RET":
                this.ip = this.call_stack[this.csp-1].ip
                this.csp -= 1
                break;
            case "MVLV":
                this.call_stack[this.csp-1].vars[operand] = this.stack.pop()
                break;
            case "PUSHLV":
                this.stack.push(this.call_stack[this.csp-1].vars[operand])
                break;
            case "ADD":{
                const b = this.stack.pop()
                const a = this.stack.pop()
                this.stack.push(a + (b*operand))
                break;
            }
            case "MUL":{
                const b = this.stack.pop()
                const a = this.stack.pop()
                this.stack.push(Math.round(a * (b**operand)))
                break;
            }
            case "EQ":{
                const b = this.stack.pop()
                const a = this.stack.pop()
                if(a == b){
                    this.stack.push(operand)
                }
                else{
                    this.stack.push(operand*-1)
                }
                break;
            }
            case "LT":{
                const b = this.stack.pop()
                const a = this.stack.pop()
                if(a < b){
                    this.stack.push(operand)
                }
                else{
                    this.stack.push(operand*-1)
                }
                break;
            }
            case "SYSCALL":{
                if(operand == 10){
                    this.consoleUpdate(this.stack.pop())
                }
                else if(operand == 11){
                    this.consoleUpdate(String.fromCharCode(this.stack.pop()))
                }
                else if(operand == 12){
                    this.stack.pop()
                    this.stack.pop()
                    this.consoleUpdate("Strings are not not currently supported.")
                }
                break
            }
            default:
                break;
        }
        this.updateUI()
        this.ip++;
        codeLines[this.ip].style.backgroundColor = "red"
        codeLines[old_ip].style.backgroundColor = "var(--background-color)"
    }
    updateUI(){
        this.stackElem.innerHTML = ""
        this.stack.forEach(number => {
            if(!isNaN(number)){
                const stackPeice = document.createElement("div")
                stackPeice.textContent = number
                this.stackElem.appendChild(stackPeice)
            }
        });
        this.callStackElem.innerHTML = ""
        this.call_stack.forEach(frame => {
                const stackPeice = document.createElement("div")
                stackPeice.textContent = frame.ip
                this.callStackElem.appendChild(stackPeice)
        });
    }

    consoleUpdate(text){
        const newText = document.createElement("div")
        newText.textContent = text
        this.consoleElem.appendChild(newText)
    }
}

const vm = new Interpreter()


document.querySelector("#loadFilepathElement").addEventListener("click", async ()=>{
    const filepath = document.querySelector("#filepathElement").value;
    const res = await fetch(filepath);
    const assemblytText = await res.text();
    loadFileTextIntoElement(assemblytText)
})

document.querySelector("#startButton").addEventListener("click", ()=>{
    vm.start()
})

window.addEventListener("keypress", e => {
    if(e.code = "Space"){
        vm.execute_instruction()
    }
})

function loadFileTextIntoElement(filetext){
    const codeSection = document.querySelector("#code")
    codeSection.innerHTML = ""
    const lines = filetext.split("\n");
    lines.forEach(line => {
        const [ip, operation, operand] = line.split(" ");
        if (ip !== undefined && operation !== undefined && operand !== undefined){
            vm.program.push([operation, operand])  
            const instructionLineElement = document.createElement("div")
            instructionLineElement.textContent = `${ip}${"  ".repeat(3 - ip.length)}${operation} ${operand}`
            codeSection.appendChild(instructionLineElement)
        }
    })
    vm.stackElem = document.querySelector("#stack");
    vm.consoleElem = document.querySelector("#console");
    vm.codeElem = codeSection
    vm.callStackElem = document.querySelector("#callStack")
    const codeLines = codeSection.querySelectorAll("div")
    if(codeLines[vm.ip]){codeLines[vm.ip].style.backgroundColor = "red"}
    
}

