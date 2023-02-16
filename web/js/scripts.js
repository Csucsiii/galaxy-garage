document.addEventListener("DOMContentLoaded", () => {
    const app = document.getElementById("app");
    app.style.display = "none";

    const createMenu = (vehicles, factionId) => {
        const ul = document.createElement("ul");
        ul.setAttribute("class", "list");
        ul.setAttribute("id", "list");
    
        const createModal = (plate, garageId) => {
            const modal = document.createElement("div");
            modal.classList.add("modal");
    
            const modalHeader = document.createElement("div");
            modalHeader.classList.add("modal-header");
    
            const modalTitle = document.createElement("div");
            modalTitle.classList.add("modal-title");
            modalTitle.textContent = "Felhívás";
    
            modalHeader.appendChild(modalTitle);
    
            const modalBody = document.createElement("div");
            modalBody.classList.add("modal-body");
            
            const modalDescription = document.createElement("div");
            modalDescription.classList.add("modal-description");
            modalDescription.textContent = "Ez az autó jelenleg le van foglalva, aminek költsége 50 dollár, szeretnéd folytatni?"
    
            const modalBtnWrapper = document.createElement("div");
            modalBtnWrapper.classList.add("modal-btn-wrapper");
            
            const modalNoBtn = document.createElement("button");
            modalNoBtn.classList.add("modal-btn");
            modalNoBtn.classList.add("no");
            modalNoBtn.textContent = "Nem";
    
            modalNoBtn.addEventListener("click", () => {
                modal.remove();
            });
    
            const modalYesBtn = document.createElement("button");
            modalYesBtn.classList.add("modal-btn");
            modalYesBtn.classList.add("yes");
            modalYesBtn.textContent = "Igen";
    
            modalYesBtn.addEventListener("click", () => {
                fetch(`https://${GetParentResourceName()}/impound`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({plate, garageId})
                }).then(() => {
                    modal.remove();
                }).catch(err => console.log(err));
            });
    
            modalBtnWrapper.appendChild(modalNoBtn);
            modalBtnWrapper.appendChild(modalYesBtn);
    
            modalBody.appendChild(modalDescription);
            modalBody.appendChild(modalBtnWrapper);
    
    
            modal.appendChild(modalHeader);
            modal.appendChild(modalBody);
    
            document.body.appendChild(modal);
        };
    
        Object.keys(vehicles).forEach((key) => {
            const vehicle = vehicles[key];

            console.log(JSON.stringify(vehicle));
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
                const cards = ul.querySelectorAll(".list-item");
                for (const v of cards){
                    if (v.textContent.toLowerCase().includes(vehicle.plate.toLowerCase())){
                        if (vehicle.impounded){
                            createModal(vehicle.plate, vehicle.garageId);
                        }else{
                            if (factionId){
                                fetch(`https://${GetParentResourceName()}/factionTakeout`, {
                                    method: "POST",
                                    headers: {
                                        "Content-Type": "application/json"
                                    },

                                    body: JSON.stringify({
                                        garageId: vehicle.garageId,
                                        plate: vehicle.plate,
                                        factionId: factionId
                                    })
                                }).then(() => {
                                    v.remove();
                                }).catch(err => console.log(err));
                            }else{
                                fetch(`https://${GetParentResourceName()}/takeout`, {
                                    method: "POST",
                                    headers: {
                                        "Content-Type": "application/json"
                                    },
    
                                    body: JSON.stringify({
                                        garageId: vehicle.garageId,
                                        plate: vehicle.plate
                                    })
                                }).then(() => {
                                    v.remove();
                                }).catch(err => console.log(err));
                            }
                           
                        }
                    }
                }
            });
    
            const img = document.createElement("img");
            img.setAttribute("src", vehicle.impounded? "./assets/key-red.png" : "./assets/key-white.png");
            img.setAttribute("class", "key-img");
    
            button.appendChild(img);
    
            li.appendChild(nameWrapper);
            li.appendChild(button);
    
            ul.appendChild(li);
        });

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
    };

    const destroyMenu = () => {
        app.style.display = "none";
        document.getElementById("list").remove();
    };

    window.addEventListener("message", (event) => {
        const data = event.data;

        if (data.status){
            if (data.vehicles){
                app.style.display = "flex";
                console.log(JSON.stringify(data.vehicles))
                createMenu(data.vehicles, data.faction);
            }
        }else{
            destroyMenu();
        }
    });

    window.addEventListener("keydown", (event) => {
        switch(event.key){
            case "Escape":{
                fetch(`https://${GetParentResourceName()}/quit`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json"
                    }
                }).catch(err => console.log(err));
            }
        }
    });
});