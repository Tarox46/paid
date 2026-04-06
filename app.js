document.addEventListener('DOMContentLoaded', () => {
    // --- State Management ---
    let employees = JSON.parse(localStorage.getItem('wage_employees')) || [];
    let todaysDateString = new Date().toLocaleDateString('en-GB', { 
        weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' 
    });
    let lastActiveDate = localStorage.getItem('wage_last_date');

    // Reset payments if it's a new day automatically
    if (lastActiveDate !== todaysDateString) {
        employees = employees.map(emp => ({ ...emp, paidToday: false }));
        localStorage.setItem('wage_last_date', todaysDateString);
        saveData();
    }

    // --- DOM Elements ---
    const dateDisplay = document.getElementById('current-date');
    const totalPaidDisplay = document.getElementById('total-paid');
    const addForm = document.getElementById('add-employee-form');
    const empNameInput = document.getElementById('emp-name');
    const empWageInput = document.getElementById('emp-wage');
    const employeeListEl = document.getElementById('employee-list');
    const resetDayBtn = document.getElementById('reset-day-btn');
    const toastContainer = document.getElementById('toast-container');

    // --- Initialization ---
    dateDisplay.textContent = todaysDateString;
    renderEmployees();
    updateStats();

    // --- Event Listeners ---
    addForm.addEventListener('submit', (e) => {
        e.preventDefault();
        
        const name = empNameInput.value.trim();
        const wage = parseFloat(empWageInput.value);

        if (name && wage > 0) {
            const newEmployee = {
                id: Date.now().toString(),
                name: name,
                wage: wage,
                paidToday: false
            };
            
            employees.push(newEmployee);
            saveData();
            renderEmployees();
            updateStats();
            
            empNameInput.value = '';
            empWageInput.value = '';
            showToast(`Added ${name} successfully!`, 'success');
        } else {
            showToast('Please enter valid details', 'error');
        }
    });

    resetDayBtn.addEventListener('click', () => {
        if(confirm('Are you sure you want to reset all payments to start a new day?')) {
            employees = employees.map(emp => ({ ...emp, paidToday: false }));
            saveData();
            renderEmployees();
            updateStats();
            showToast('New day started. All payments reset.', 'success');
        }
    });

    // --- Core Functions ---
    function renderEmployees() {
        if (employees.length === 0) {
            employeeListEl.innerHTML = `
                <div class="empty-state">
                    <ion-icon name="people-outline"></ion-icon>
                    <p>No employees found. Add one above.</p>
                </div>
            `;
            return;
        }

        employeeListEl.innerHTML = '';
        
        employees.forEach(emp => {
            const card = document.createElement('div');
            card.className = 'employee-card';
            
            card.innerHTML = `
                <div class="employee-info">
                    <span class="employee-name">${emp.name}</span>
                    <span class="employee-wage">฿${emp.wage.toLocaleString('en-US')} / day</span>
                </div>
                <div class="employee-actions">
                    <button class="btn-pay ${emp.paidToday ? 'paid' : ''}" 
                            onclick="window.togglePayment('${emp.id}')"
                            ${emp.paidToday ? 'disabled' : ''}>
                        <ion-icon name="${emp.paidToday ? 'checkmark-circle' : 'wallet-outline'}"></ion-icon>
                        ${emp.paidToday ? 'Paid' : 'Pay'}
                    </button>
                    <button class="btn-delete" onclick="window.deleteEmployee('${emp.id}')" aria-label="Delete">
                        <ion-icon name="trash-outline"></ion-icon>
                    </button>
                </div>
            `;
            employeeListEl.appendChild(card);
        });
    }

    function updateStats() {
        const totalPaid = employees
            .filter(emp => emp.paidToday)
            .reduce((sum, emp) => sum + emp.wage, 0);
            
        totalPaidDisplay.textContent = `฿${totalPaid.toLocaleString('en-US')}`;
    }

    function saveData() {
        localStorage.setItem('wage_employees', JSON.stringify(employees));
    }

    function showToast(message, type = 'success') {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        
        const iconName = type === 'success' ? 'checkmark-circle' : 'alert-circle';
        
        toast.innerHTML = `
            <ion-icon name="${iconName}"></ion-icon>
            <span>${message}</span>
        `;
        
        toastContainer.appendChild(toast);
        
        setTimeout(() => {
            toast.style.animation = 'toastFadeOut 0.3s ease forwards';
            setTimeout(() => {
                if(toastContainer.contains(toast)) {
                    toastContainer.removeChild(toast);
                }
            }, 300);
        }, 3000);
    }

    // --- Global Functions for inline event handlers ---
    window.togglePayment = (id) => {
        const index = employees.findIndex(emp => emp.id === id);
        if (index !== -1) {
            employees[index].paidToday = !employees[index].paidToday;
            saveData();
            renderEmployees();
            updateStats();
            
            if(employees[index].paidToday) {
                showToast(`Paid ฿${employees[index].wage} to ${employees[index].name} !`, 'success');
            }
        }
    };

    window.deleteEmployee = (id) => {
        const emp = employees.find(e => e.id === id);
        if (confirm(`Remove ${emp.name} from the list?`)) {
            employees = employees.filter(e => e.id !== id);
            saveData();
            renderEmployees();
            updateStats();
            showToast(`${emp.name} removed.`, 'success');
        }
    };
});
