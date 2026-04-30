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

const revealItems = document.querySelectorAll(".reveal");
if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });

  revealItems.forEach((item) => observer.observe(item));
} else {
  revealItems.forEach((item) => item.classList.add("visible"));
}

(function () {
  function ready(fn) {
    if (document.readyState !== "loading") fn();
    else document.addEventListener("DOMContentLoaded", fn);
  }

  ready(function () {
    const toggle = document.getElementById("id-chat-toggle-v2");
    const close = document.getElementById("id-chat-close-v2");
    const chatWindow = document.getElementById("id-chat-window-v2");
    const chatBody = document.getElementById("id-chat-body-v2");
    const facebookLink = "https://www.facebook.com/IntelliumDigitalPH";

    if (!toggle || !chatWindow || !chatBody) return;

    function addMessage(type, message) {
      const div = document.createElement("div");
      div.className = type === "user" ? "id-user-message-v2" : "id-bot-message-v2";
      div.innerHTML = message;
      chatBody.appendChild(div);
      chatBody.scrollTop = chatBody.scrollHeight;
    }

    const replies = {
      website: {
        user: "I need a website",
        bot: "Great choice! 🚀<br><br>We build premium, mobile-friendly websites for startups, SMEs, freelancers, and local business owners.<br><br>Website pricing starts at <strong>₱5,000</strong>.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Message us on Facebook</a>"
      },
      maya: {
        user: "I need a website with Maya payment",
        bot: "Perfect! 💳<br><br>Our Website + Maya Integration promo is designed for rentals, services, booking businesses, and small businesses that want online payment readiness.<br><br>Launch promo: <strong>₱18,000</strong>.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Claim Website + Maya Promo</a>"
      },
      app: {
        user: "I need an app",
        bot: "Awesome! 📱<br><br>We can help plan and build business apps for booking, tracking, customer access, loyalty, referrals, and digital service platforms.<br><br>App development starts at <strong>₱35,000+</strong>.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Discuss your app idea</a>"
      },
      sweldotrack: {
        user: "I want SweldoTrack",
        bot: "Nice! 💸<br><br>SweldoTrack is our Filipino-friendly salary and expense tracker for sweldo, bills, savings, utang, daily spending limits, analytics, and invite-to-earn.<br><br>You can message us to join Android testing or ask how we can build a similar app for your business.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Ask about SweldoTrack</a>"
      },
      branding: {
        user: "I need branding/logo",
        bot: "Perfect! 🎨<br><br>We help businesses look professional with logo design, cover photos, profile images, brand colors, and social media visuals.<br><br>Branding starts at <strong>₱3,500+</strong>.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Request branding help</a>"
      },
      pricing: {
        user: "What are your prices?",
        bot: "Here are the starting prices: 💼<br><br>• Branding / Logo: <strong>₱3,500+</strong><br>• Starter Website: <strong>₱5,000+</strong><br>• Business Website: <strong>₱10,000+</strong><br>• Website + Maya Promo: <strong>₱18,000</strong><br>• Full Digital Setup: <strong>₱25,000+</strong><br>• Business App: <strong>₱35,000+</strong><br><br>Final quote depends on pages, features, design, content, and integrations.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Get a quote</a>"
      },
      budget: {
        user: "I want to discuss my budget",
        bot: "No problem! 🤝<br><br>Tell us your budget, business type, and what you want to build. We will recommend the most realistic package for your goal.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Discuss my budget</a>"
      },
      start: {
        user: "Start my project ASAP",
        bot: "Let's go! 🚀<br><br>Please send us:<br>• Business name<br>• Type of business<br>• Services/products offered<br>• Preferred design style<br>• Target budget<br>• Target launch date<br><br>We will guide you from planning to launch.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Message Intellium Digital</a>"
      }
    };

    toggle.addEventListener("click", () => {
      chatWindow.style.display = chatWindow.style.display === "block" ? "none" : "block";
    });

    if (close) close.addEventListener("click", () => chatWindow.style.display = "none");

    document.querySelectorAll("[data-chat-option]").forEach((button) => {
      button.addEventListener("click", () => {
        const selected = replies[button.getAttribute("data-chat-option")];
        if (!selected) return;
        addMessage("user", selected.user);
        setTimeout(() => addMessage("bot", selected.bot), 350);
      });
    });

    toggle.style.display = "flex";
  });
})();

document.querySelectorAll(".xendit-pay-btn").forEach((button) => {
  button.addEventListener("click", async () => {
    const originalText = button.textContent;
    const packageName = button.dataset.name;
    const amount = Number(button.dataset.amount);
    button.disabled = true;
    button.textContent = "Creating secure checkout...";
    try {
      const response = await fetch("/api/create-xendit-invoice", {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({ packageName, amount })
      });
      const data = await response.json();
      if (!response.ok || !data.invoice_url) throw new Error(data.error || "Unable to create Xendit checkout.");
      window.location.href = data.invoice_url;
    } catch (error) {
      console.error(error);
      alert("We could not create the checkout link. Please message Intellium Digital first or try again later.");
      button.disabled = false;
      button.textContent = originalText;
    }
  });
});
