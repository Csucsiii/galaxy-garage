const data = [
    {
        plate: "ABC123AB",
        name: "La Ferrari",
        impounded: true
    },
    {
        plate: "ABC123AC",
        name: "Mercedes E62"
    },
    {
        plate: "XYZ987XY",
        name: "BMW M8"
    },
    {
        plate: "ABC123AL",
        name: "Audi RS6"
    },
    {
        plate: "XYZ987XU",
        name: "Audi RS6"
    },
    {
        plate: "ABC123AA",
        name: "BMW M8"
    },
    {
        plate: "XYZ987XG",
        name: "Mercedes E62"
    },
    {
        plate: "ABC123AN",
        name: "Dodge SRT"
    },
    {
        plate: "XYZ987XA",
        name: "La Ferrari"
    }
];

document.addEventListener("DOMContentLoaded", () => {
    const app = document.getElementById("app");
    
    const ul = document.createElement("ul");
    ul.setAttribute("class", "list");


    data.forEach((vehicle, index) => {
        const li = document.createElement("li");
        li.setAttribute("class", "list-item")

        const nameWrapper = document.createElement("div");
        nameWrapper.setAttribute("class", "name-wrapper");

        const name = document.createElement("div");
        name.textContent = vehicle.name;

        const plate = document.createElement("div");
        plate.setAttribute("class", "plate");
        plate.textContent = `(${vehicle.plate})`;

        nameWrapper.appendChild(name);
        nameWrapper.appendChild(plate);

        const button = document.createElement("button");
        button.setAttribute("class", "key-button");
        button.addEventListener("click", () => {
            console.log("vehicle", vehicle.plate);
            const cards = ul.querySelectorAll(".list-item");

            for (const v of cards){
                if (v.textContent.toLowerCase().includes(vehicle.plate.toLowerCase())){
                    v.remove();
                }
            }
            console.log(cards);
        });

        const img = document.createElement("img");
        img.setAttribute("src", vehicle.impounded? "./assets/key-red.png" : "./assets/key-white.png");
        img.setAttribute("class", "key-img");

        button.appendChild(img);

        li.appendChild(nameWrapper);
        li.appendChild(button);

        ul.appendChild(li);
    })

    app.appendChild(ul);

    const searchInput = document.getElementById("search");


    searchInput.addEventListener("input", () => {
        const vehicles = ul.querySelectorAll(".list-item");
        const searchQuery = searchInput.value;

        for (const v of vehicles){
            if (v.innerText.toLowerCase().includes(searchQuery.toLowerCase())){
                v.classList.remove("hidden");
            }else{
                v.classList.add("hidden");
            }
        }
    })
});