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


// Intellium Digital Free Messenger-Style Chatbot
function toggleChat() {
  const chatWindow = document.getElementById("chat-window");
  if (!chatWindow) return;
  chatWindow.style.display = chatWindow.style.display === "block" ? "none" : "block";
}

function addMessage(type, message) {
  const chatBody = document.getElementById("chat-body");
  if (!chatBody) return;
  const div = document.createElement("div");
  div.className = type === "user" ? "user-message" : "bot-message";
  div.innerHTML = message;
  chatBody.appendChild(div);
  chatBody.scrollTop = chatBody.scrollHeight;
}

function replyBot(service) {
  const facebookLink = "https://www.facebook.com/IntelliumDigitalPH";
  const replies = {
    website: {
      user: "I need a website",
      bot: `
        Great choice! 🚀<br><br>
        We build professional, mobile-friendly websites for startups, SMEs, freelancers, and local business owners.
        <br><br>
        Best for: service pages, landing pages, inquiries, credibility, and launch campaigns.
        <br><br>
        Website pricing starts at <strong>₱5,000</strong>.
        <br>
        <a class="chat-cta" href="${facebookLink}" target="_blank" rel="noopener">Message us on Facebook</a>
      `
    },
    maya: {
      user: "I need a website with Maya payment",
      bot: `
        Perfect! 💳<br><br>
        Our Website + Maya Integration promo is designed for rentals, services, booking businesses, and small businesses that want online payment readiness.
        <br><br>
        Launch promo: <strong>₱18,000</strong>. Includes website, Maya payment-ready section, inquiry/booking form, Messenger CTA, mobile-friendly design, and basic SEO setup.
        <br>
        <a class="chat-cta" href="${facebookLink}" target="_blank" rel="noopener">Claim Website + Maya Promo</a>
      `
    },
    app: {
      user: "I need an app",
      bot: `
        Awesome! 📱<br><br>
        We can help plan and build business apps for booking, tracking, customer access, loyalty, referrals, and digital service platforms.
        <br><br>
        App development starts at <strong>₱35,000+</strong>, depending on features and complexity.
        <br>
        <a class="chat-cta" href="${facebookLink}" target="_blank" rel="noopener">Discuss your app idea</a>
      `
    },
    branding: {
      user: "I need branding/logo",
      bot: `
        Perfect! 🎨<br><br>
        We help businesses look professional with logo design, cover photos, profile images, brand colors, and social media visuals.
        <br><br>
        Branding starts at <strong>₱3,500+</strong>.
        <br>
        <a class="chat-cta" href="${facebookLink}" target="_blank" rel="noopener">Request branding help</a>
      `
    },
    ads: {
      user: "I need Facebook ads",
      bot: `
        Nice! 📣<br><br>
        We help with Facebook ads setup for engagement, leads, inquiries, and service promotions.
        <br><br>
        We can prepare ad creatives, captions, targeting ideas, quick replies, and lead flow.
        <br>
        <a class="chat-cta" href="${facebookLink}" target="_blank" rel="noopener">Start Facebook ads</a>
      `
    },
    social: {
      user: "I need social media marketing",
      bot: `
        Great! 🔥<br><br>
        We can help with content planning, captions, posters, reels ideas, branding, and launch posts.
        <br><br>
        Best for businesses that want to look active, credible, and ready for customers online.
        <br>
        <a class="chat-cta" href="${facebookLink}" target="_blank" rel="noopener">Ask for social media help</a>
      `
    },
    pricing: {
      user: "What are your prices?",
      bot: `
        Here are the starting prices: 💼<br><br>
        • Branding / Logo: <strong>₱3,500+</strong><br>
        • Starter Website: <strong>₱5,000+</strong><br>
        • Business Website: <strong>₱10,000+</strong><br>
        • Website + Maya Promo: <strong>₱18,000</strong><br>
        • Full Digital Setup: <strong>₱25,000+</strong><br>
        • Business App: <strong>₱35,000+</strong><br><br>
        Final quote depends on pages, features, design, content, and integrations.
        <br>
        <a class="chat-cta" href="${facebookLink}" target="_blank" rel="noopener">Get a quote</a>
      `
    },
    budget: {
      user: "I want to discuss my budget",
      bot: `
        No problem! 🤝<br><br>
        Tell us your budget, business type, and what you want to build. We will recommend the most realistic package for your goal.
        <br><br>
        Even if you are starting small, we can suggest a clean starter setup.
        <br>
        <a class="chat-cta" href="${facebookLink}" target="_blank" rel="noopener">Discuss my budget</a>
      `
    },
    start: {
      user: "Start my project ASAP",
      bot: `
        Let's go! 🚀<br><br>
        Please send us:<br>
        • Business name<br>
        • Type of business<br>
        • Services/products offered<br>
        • Preferred design style<br>
        • Target budget<br>
        • Target launch date<br><br>
        We will guide you from planning to launch.
        <br>
        <a class="chat-cta" href="${facebookLink}" target="_blank" rel="noopener">Message Intellium Digital</a>
      `
    }
  };

  const selected = replies[service];
  if (!selected) return;
  addMessage("user", selected.user);
  setTimeout(() => addMessage("bot", selected.bot), 450);
}
