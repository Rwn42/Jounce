document.querySelector("#loadFilepathElement").addEventListener("click", async ()=>{
    const filepath = document.querySelector("#filepathElement").value;
    const res = await fetch(filepath);
    const assemblytText = await res.text();
    loadFileTextIntoElement(assemblytText)
})

function loadFileTextIntoElement(filetext){
    const ipSection = document.querySelector("#ip")
    const lines = filetext.split("\n");
    lines.forEach(line => {
        const [ip, operation, operand] = line.split(" ");
        const ipElement = document.createElement("p")
        ipElement.textContent = ip;
        ipSection.appendChild(ipElement)
    })
}