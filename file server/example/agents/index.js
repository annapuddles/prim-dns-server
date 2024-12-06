window.addEventListener('load', function() {
    fetch('agents.json').then(resp => resp.json()).then(agents => {
        document.getElementById('region-name').innerHTML = agents.region;

        let table = document.getElementById('agents-table');

        agents.agentList.forEach(agent => {
            let row = document.createElement('tr');

            let col1 = document.createElement('td');
            col1.innerText = agent.key;
            row.append(col1);

            let col2 = document.createElement('td');
            col2.innerText = agent.displayName;
            row.append(col2);
            
            let col3 = document.createElement('td');
            col3.innerText = agent.username;
            row.append(col3);
            
            let col4 = document.createElement('td');
            col4.innerText = agent.position;
            row.append(col4);

            table.append(row);
        });
    });
});
