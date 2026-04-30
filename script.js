const menuBtn = document.getElementById("menuBtn");
const navMenu = document.getElementById("navMenu");

if (menuBtn && navMenu) {
  menuBtn.addEventListener("click", () => navMenu.classList.toggle("active"));
  navMenu.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => navMenu.classList.remove("active"));
  });
}

const leadForm = document.getElementById("leadForm");

if (leadForm) {
  leadForm.addEventListener("submit", (event) => {
    event.preventDefault();

    const name = document.getElementById("name").value.trim();
    const business = document.getElementById("business").value.trim();
    const contactInfo = document.getElementById("contactInfo").value.trim();
    const service = document.getElementById("service").value;
    const budgetRange = document.getElementById("budgetRange").value;
    const message = document.getElementById("message").value.trim();

    const subject = encodeURIComponent(`New Intellium Digital Inquiry - ${business}`);
    const body = encodeURIComponent(
      `Hello Intellium Digital,\n\nI would like to inquire about your services.\n\nName: ${name}\nBusiness Name: ${business}\nContact: ${contactInfo}\nService Needed: ${service}\nEstimated Budget: ${budgetRange}\n\nMessage:\n${message}\n\nThank you.`
    );

    window.location.href = `mailto:intelliumdigital@gmail.com?subject=${subject}&body=${body}`;
  });
}
