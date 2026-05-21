const menuBtn = document.getElementById("menuBtn");
const navMenu = document.getElementById("navMenu");

if (menuBtn && navMenu) {
  menuBtn.addEventListener("click", () => {
    const isOpen = navMenu.classList.toggle("active");
    menuBtn.setAttribute("aria-expanded", String(isOpen));
  });

  navMenu.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      navMenu.classList.remove("active");
      menuBtn.setAttribute("aria-expanded", "false");
    });
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
      `Hello Intellium Digital,\n\n` +
      `I would like to inquire about your services.\n\n` +
      `Name: ${name}\n` +
      `Business Name: ${business}\n` +
      `Contact: ${contactInfo}\n` +
      `Service Needed: ${service}\n` +
      `Estimated Budget: ${budgetRange || "Not specified"}\n\n` +
      `Project Details:\n${message || "No additional message provided."}\n\n` +
      `Thank you.`
    );

    window.location.href = `mailto:intelliumdigital@gmail.com?subject=${subject}&body=${body}`;
  });
}

const revealItems = document.querySelectorAll(".reveal");
const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

if (prefersReducedMotion) {
  revealItems.forEach((item) => item.classList.add("visible"));
} else {
  revealItems.forEach((item, index) => {
    const delay = Math.min(index * 45, 270);
    item.style.setProperty("--delay", `${delay}ms`);
  });

  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) {
          return;
        }

        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.16 });

    revealItems.forEach((item) => observer.observe(item));
  } else {
    revealItems.forEach((item) => item.classList.add("visible"));
  }
}

(function () {
  function ready(fn) {
    if (document.readyState !== "loading") {
      fn();
      return;
    }

    document.addEventListener("DOMContentLoaded", fn);
  }

  ready(() => {
    const toggle = document.getElementById("id-chat-toggle-v2");
    const close = document.getElementById("id-chat-close-v2");
    const chatWindow = document.getElementById("id-chat-window-v2");
    const chatBody = document.getElementById("id-chat-body-v2");
    const facebookLink = "https://www.facebook.com/IntelliumDigitalPH";

    if (!toggle || !chatWindow || !chatBody) {
      return;
    }

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
        bot: "Intellium Digital creates premium business websites designed to strengthen trust, clarify your offer, and turn more visitors into qualified inquiries.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Discuss your website</a>"
      },
      maya: {
        user: "I need website + Maya",
        bot: "The Website + Maya package is ideal for service businesses that want a more seamless path from inquiry to payment. Final approval still depends on Maya or the payment provider's requirements.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Ask about the Maya promo</a>"
      },
      app: {
        user: "I need an app",
        bot: "Intellium Digital designs and builds business apps for bookings, tracking, operations, and customer access. Custom app projects usually start at PHP 35,000.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Discuss your app idea</a>"
      },
      sweldotrack: {
        user: "Tell me about SweldoTrack",
        bot: "SweldoTrack is Intellium Digital's featured budgeting product focused on salary, bills, savings, utang, and everyday expense management for Filipino users.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Ask about SweldoTrack</a>"
      },
      branding: {
        user: "I need branding",
        bot: "Branding support includes logo direction, profile visuals, cover graphics, color systems, and social assets that make your business look more established.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Request branding help</a>"
      },
      pricing: {
        user: "Show pricing",
        bot: "Public starting prices currently include Branding from PHP 3,500, Starter Websites from PHP 5,000, Business Websites from PHP 10,000, Website + Maya at PHP 18,000, Full Digital Setup from PHP 25,000, and Business Apps from PHP 35,000.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Request a quote</a>"
      },
      budget: {
        user: "I have a budget in mind",
        bot: "Send your budget, business type, and goals, and Intellium Digital will recommend the strongest scope for that range.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Discuss your budget</a>"
      },
      start: {
        user: "Start my project",
        bot: "To get started, prepare your business name, business type, preferred style, budget range, target launch date, and priority deliverables.<br><a class='id-chat-cta-v2' href='" + facebookLink + "' target='_blank' rel='noopener'>Start your project</a>"
      }
    };

    toggle.addEventListener("click", () => {
      chatWindow.style.display = chatWindow.style.display === "block" ? "none" : "block";
    });

    if (close) {
      close.addEventListener("click", () => {
        chatWindow.style.display = "none";
      });
    }

    document.querySelectorAll("[data-chat-option]").forEach((button) => {
      button.addEventListener("click", () => {
        const selected = replies[button.getAttribute("data-chat-option")];
        if (!selected) {
          return;
        }

        addMessage("user", selected.user);
        window.setTimeout(() => addMessage("bot", selected.bot), 250);
      });
    });
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
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ packageName, amount })
      });

      const data = await response.json();

      if (!response.ok || !data.invoice_url) {
        throw new Error(data.error || "Unable to create Xendit checkout.");
      }

      window.location.href = data.invoice_url;
    } catch (error) {
      console.error(error);
      alert("We could not create the checkout link. Please message Intellium Digital first or try again later.");
      button.disabled = false;
      button.textContent = originalText;
    }
  });
});
