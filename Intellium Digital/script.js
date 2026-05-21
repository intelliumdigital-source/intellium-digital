const PRODUCTS = [
  { id: "basic-logo-design", category: "Branding", name: "Basic Logo Design", price: 1500, displayPrice: "₱1,500", type: "fixed", description: "Clean starter logo for small businesses." },
  { id: "premium-logo-design", category: "Branding", name: "Premium Logo Design", price: 2500, displayPrice: "₱2,500", type: "fixed", description: "More polished logo concept with premium styling." },
  { id: "facebook-profile-cover", category: "Branding", name: "Facebook Profile + Cover Photo", price: 1500, displayPrice: "₱1,500", type: "fixed", description: "Branded Facebook visuals for business pages." },
  { id: "brand-color-font-guide", category: "Branding", name: "Brand Color + Font Guide", price: 1000, displayPrice: "₱1,000", type: "fixed", description: "Basic visual guide for consistent branding." },
  { id: "branding-kit-bundle", category: "Branding", name: "Branding Kit Bundle", price: 3500, displayPrice: "₱3,500", type: "fixed", description: "Logo, colors, fonts, and basic brand guide." },

  { id: "starter-website-5-pages", category: "Websites", name: "Starter Website, up to 5 pages", price: 5000, displayPrice: "₱5,000", type: "fixed", description: "Mobile-friendly starter website with inquiry form." },
  { id: "business-website-10-pages", category: "Websites", name: "Business Website, up to 10 pages", price: 10000, displayPrice: "₱10,000", type: "fixed", description: "Premium business website with improved sections and inquiry flow." },
  { id: "premium-website-redesign", category: "Websites", name: "Premium Website Redesign", price: 12000, displayPrice: "₱12,000", type: "fixed", description: "Upgrade an existing website into a more polished brand experience." },
  { id: "booking-inquiry-form-setup", category: "Websites", name: "Booking / Inquiry Form Setup", price: 2000, displayPrice: "₱2,000", type: "fixed", description: "Add a form flow for inquiries, bookings, or reservations." },
  { id: "website-copywriting-setup", category: "Websites", name: "Website Copywriting Setup", price: 2500, displayPrice: "₱2,500", type: "fixed", description: "Help organize and write clearer website copy." },
  { id: "extra-page", category: "Websites", name: "Extra Page", price: 1000, displayPrice: "₱1,000", type: "fixed", description: "Additional website page for existing website packages." },

  { id: "maya-checkout-button-setup", category: "Maya Checkout", name: "Maya Checkout Button Setup", price: 4000, displayPrice: "₱4,000", type: "fixed", description: "Add secure Maya Checkout buttons to your website." },
  { id: "product-service-checkout-flow", category: "Maya Checkout", name: "Product / Service Checkout Flow", price: 6000, displayPrice: "₱6,000", type: "fixed", description: "Organize services or products into a checkout-ready flow." },
  { id: "maya-webhook-payment-status-setup", category: "Maya Checkout", name: "Maya Webhook / Payment Status Setup", price: 5000, displayPrice: "₱5,000", type: "fixed", description: "Add backend payment notification handling." },
  { id: "success-failed-payment-pages", category: "Maya Checkout", name: "Success / Failed Payment Pages", price: 2000, displayPrice: "₱2,000", type: "fixed", description: "Add branded payment result pages." },
  { id: "website-maya-integration-promo", category: "Maya Checkout", name: "Website + Maya Integration Promo", price: 18000, displayPrice: "₱18,000", type: "featured", description: "Business website with Maya-ready checkout flow, payment buttons, and launch support." },

  { id: "basic-seo-setup", category: "SEO & Marketing", name: "Basic SEO Setup", price: 2500, displayPrice: "₱2,500", type: "fixed", description: "Basic titles, descriptions, and SEO-ready page structure." },
  { id: "google-search-console-setup", category: "SEO & Marketing", name: "Google Search Console Setup", price: 1500, displayPrice: "₱1,500", type: "fixed", description: "Prepare the website for Google Search Console verification." },
  { id: "seo-page-titles-meta-descriptions", category: "SEO & Marketing", name: "SEO Page Titles + Meta Descriptions", price: 2000, displayPrice: "₱2,000", type: "fixed", description: "Improve website search snippets and page clarity." },
  { id: "local-business-seo-setup", category: "SEO & Marketing", name: "Local Business SEO Setup", price: 3500, displayPrice: "₱3,500", type: "fixed", description: "Setup for local search visibility and business credibility." },
  { id: "basic-sem-ads-launch-setup", category: "SEO & Marketing", name: "Basic SEM / Ads Launch Setup", price: 4000, displayPrice: "₱4,000", type: "fixed", description: "Basic ad campaign launch preparation." },

  { id: "auto-reply-faq-setup", category: "Automation", name: "Auto-reply / FAQ Setup", price: 2500, displayPrice: "₱2,500", type: "fixed", description: "Prepare common replies and FAQ flow for inquiries." },
  { id: "lead-capture-form-google-sheet", category: "Automation", name: "Lead Capture Form + Google Sheet", price: 3000, displayPrice: "₱3,000", type: "fixed", description: "Send inquiries into a simple lead tracker." },
  { id: "booking-request-flow", category: "Automation", name: "Booking Request Flow", price: 3500, displayPrice: "₱3,500", type: "fixed", description: "Create a simple booking request process." },
  { id: "email-notification-automation", category: "Automation", name: "Email Notification Automation", price: 2500, displayPrice: "₱2,500", type: "fixed", description: "Send email alerts when customers submit forms." },
  { id: "basic-business-automation-bundle", category: "Automation", name: "Basic Business Automation Bundle", price: 8000, displayPrice: "₱8,000", type: "fixed", description: "Lead capture, notifications, and simple workflow setup." },

  { id: "app-ui-mockup-prototype", category: "Apps", name: "App UI Mockup / Prototype", price: 8000, displayPrice: "₱8,000", type: "fixed", description: "App screens and user flow prototype." },
  { id: "simple-web-app", category: "Apps", name: "Simple Web App", price: 20000, displayPrice: "₱20,000+", type: "quote", description: "Starter custom web app. Requires quote confirmation." },
  { id: "business-mobile-app", category: "Apps", name: "Business Mobile App", price: 35000, displayPrice: "₱35,000+", type: "quote", description: "Custom mobile app starting price. Requires quote confirmation." },
  { id: "admin-dashboard", category: "Apps", name: "Admin Dashboard", price: 15000, displayPrice: "₱15,000+", type: "quote", description: "Admin panel or internal business dashboard. Requires quote confirmation." },
  { id: "custom-app-quotation", category: "Apps", name: "Custom App Quotation", price: 35000, displayPrice: "Starts at ₱35,000", type: "quote", description: "Custom app quotation based on project scope." },

  { id: "starter-digital-presence-bundle", category: "Bundles", name: "Starter Digital Presence", price: 5000, displayPrice: "₱5,000", type: "fixed", description: "Basic website, inquiry form, mobile-friendly design, and basic SEO." },
  { id: "business-website-package-bundle", category: "Bundles", name: "Business Website Package", price: 10000, displayPrice: "₱10,000", type: "fixed", description: "Up to 10 pages, premium design, speed optimization, and inquiry flow." },
  { id: "full-digital-business-setup-bundle", category: "Bundles", name: "Full Digital Business Setup", price: 25000, displayPrice: "₱25,000", type: "fixed", description: "Branding, website, Maya setup, SEO, automation, and launch support." },
  { id: "business-app-starter-bundle", category: "Bundles", name: "Business App Starter", price: 35000, displayPrice: "₱35,000+", type: "quote", description: "Custom web or mobile app starting package. Requires quote confirmation." }
];

const CART_STORAGE_KEY = "intellium-digital-cart-v1";
const CART_NOTE_STORAGE_KEY = "intellium-digital-cart-note-v1";
const FACEBOOK_LINK = "https://www.facebook.com/IntelliumDigitalPH";

const productMap = new Map(PRODUCTS.map((product) => [product.id, product]));
let currentFilter = "All";
let cart = loadCart();

const menuBtn = document.getElementById("menuBtn");
const navMenu = document.getElementById("navMenu");
const leadForm = document.getElementById("leadForm");
const catalogGrid = document.getElementById("catalogGrid");
const catalogFilters = document.getElementById("catalogFilters");
const cartItemsContainer = document.getElementById("cartItems");
const cartSubtotal = document.getElementById("cartSubtotal");
const catalogCheckoutBtn = document.getElementById("catalogCheckoutBtn");
const mobileCartCount = document.getElementById("mobileCartCount");
const mobileCartSubtotal = document.getElementById("mobileCartSubtotal");
const mobileCartBar = document.getElementById("mobileCartBar");
const mobileCartToggleBtn = document.getElementById("mobileCartToggleBtn");
const cartPanel = document.getElementById("cartPanel");
const cartCloseBtn = document.getElementById("cartCloseBtn");
const customerNoteInput = document.getElementById("customerNote");

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
        bot: "Intellium Digital creates premium business websites designed to strengthen trust, clarify your offer, and turn more visitors into qualified inquiries.<br><a class='id-chat-cta-v2' href='" + FACEBOOK_LINK + "' target='_blank' rel='noopener'>Discuss your website</a>"
      },
      maya: {
        user: "I need website + Maya",
        bot: "The Website + Maya package is ideal for service businesses that want a more seamless path from inquiry to payment. Final approval still depends on Maya or the payment provider's requirements.<br><a class='id-chat-cta-v2' href='" + FACEBOOK_LINK + "' target='_blank' rel='noopener'>Ask about the Maya promo</a>"
      },
      app: {
        user: "I need an app",
        bot: "Intellium Digital designs and builds business apps for bookings, tracking, operations, and customer access. Custom app projects usually start at PHP 35,000.<br><a class='id-chat-cta-v2' href='" + FACEBOOK_LINK + "' target='_blank' rel='noopener'>Discuss your app idea</a>"
      },
      sweldotrack: {
        user: "Tell me about SweldoTrack",
        bot: "SweldoTrack is Intellium Digital's featured budgeting product focused on salary, bills, savings, utang, and everyday expense management for Filipino users.<br><a class='id-chat-cta-v2' href='" + FACEBOOK_LINK + "' target='_blank' rel='noopener'>Ask about SweldoTrack</a>"
      },
      branding: {
        user: "I need branding",
        bot: "Branding support includes logo direction, profile visuals, cover graphics, color systems, and social assets that make your business look more established.<br><a class='id-chat-cta-v2' href='" + FACEBOOK_LINK + "' target='_blank' rel='noopener'>Request branding help</a>"
      },
      pricing: {
        user: "Show pricing",
        bot: "Browse the catalog section for fixed-price services that can be combined into one secure Maya Checkout. Quote-only services are marked separately when scope confirmation is required.<br><a class='id-chat-cta-v2' href='#service-catalog'>Open the catalog</a>"
      },
      budget: {
        user: "I have a budget in mind",
        bot: "Send your budget, business type, and goals, and Intellium Digital will recommend the strongest scope for that range.<br><a class='id-chat-cta-v2' href='" + FACEBOOK_LINK + "' target='_blank' rel='noopener'>Discuss your budget</a>"
      },
      start: {
        user: "Start my project",
        bot: "To get started, prepare your business name, business type, preferred style, budget range, target launch date, and priority deliverables.<br><a class='id-chat-cta-v2' href='" + FACEBOOK_LINK + "' target='_blank' rel='noopener'>Start your project</a>"
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

function loadCart() {
  try {
    const stored = JSON.parse(localStorage.getItem(CART_STORAGE_KEY) || "[]");
    return stored
      .filter((item) => productMap.has(item.id))
      .map((item) => ({
        id: item.id,
        quantity: Number.isInteger(item.quantity) && item.quantity > 0 ? item.quantity : 1
      }));
  } catch {
    return [];
  }
}

function saveCart() {
  localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(cart));
}

function formatCurrency(value) {
  return new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
    maximumFractionDigits: 0
  }).format(value);
}

function getCartDetailedItems() {
  return cart
    .map((cartItem) => {
      const product = productMap.get(cartItem.id);
      if (!product || product.type === "quote") {
        return null;
      }

      return {
        ...product,
        quantity: cartItem.quantity,
        lineTotal: product.price * cartItem.quantity
      };
    })
    .filter(Boolean);
}

function getCartSubtotalValue() {
  return getCartDetailedItems().reduce((sum, item) => sum + item.lineTotal, 0);
}

function renderCatalog() {
  if (!catalogGrid) {
    return;
  }

  const filteredProducts = PRODUCTS.filter((product) => currentFilter === "All" || product.category === currentFilter);

  catalogGrid.innerHTML = filteredProducts.map((product) => {
    const actionLabel = product.type === "quote" ? "Request Quote" : "Add to Cart";
    const actionClass = product.type === "quote" ? "catalog-action" : "catalog-action primary";
    const actionAttrs = product.type === "quote"
      ? `data-quote-id="${product.id}"`
      : `data-add-id="${product.id}"`;

    return `
      <article class="product-card glass-3d depth-card premium-surface neon-edge ${product.type === "featured" ? "featured glow-card" : ""} reveal">
        <span class="category-badge">${product.category}</span>
        <h3>${product.name}</h3>
        <strong>${product.displayPrice}</strong>
        <p class="product-description">${product.description}</p>
        <div class="product-actions">
          <button class="${actionClass}" type="button" ${actionAttrs}>${actionLabel}</button>
        </div>
      </article>
    `;
  }).join("");

  if (!prefersReducedMotion) {
    catalogGrid.querySelectorAll(".reveal").forEach((item) => item.classList.add("visible"));
  }
}

function renderCart() {
  if (!cartItemsContainer || !cartSubtotal || !catalogCheckoutBtn || !mobileCartCount || !mobileCartSubtotal) {
    return;
  }

  const items = getCartDetailedItems();
  const subtotal = getCartSubtotalValue();
  const totalCount = items.reduce((sum, item) => sum + item.quantity, 0);

  if (!items.length) {
    cartItemsContainer.innerHTML = `<p class="empty-cart">Your cart is empty.</p>`;
  } else {
    cartItemsContainer.innerHTML = items.map((item) => `
      <article class="cart-item">
        <div class="cart-item-top">
          <div>
            <div class="cart-item-name">${item.name}</div>
            <div class="cart-item-meta">${item.displayPrice} each</div>
          </div>
          <div class="cart-item-price">${formatCurrency(item.lineTotal)}</div>
        </div>
        <div class="cart-item-controls">
          <div class="qty-controls">
            <button class="qty-btn" type="button" data-qty-id="${item.id}" data-delta="-1">-</button>
            <span>${item.quantity}</span>
            <button class="qty-btn" type="button" data-qty-id="${item.id}" data-delta="1">+</button>
          </div>
          <button class="remove-btn" type="button" data-remove-id="${item.id}">Remove</button>
        </div>
      </article>
    `).join("");
  }

  cartSubtotal.textContent = formatCurrency(subtotal);
  mobileCartSubtotal.textContent = formatCurrency(subtotal);
  mobileCartCount.textContent = `${totalCount} item${totalCount === 1 ? "" : "s"}`;
  catalogCheckoutBtn.disabled = items.length === 0;
}

function addToCart(productId) {
  const product = productMap.get(productId);
  if (!product || product.type === "quote") {
    return;
  }

  const existing = cart.find((item) => item.id === productId);
  if (existing) {
    existing.quantity += 1;
  } else {
    cart.push({ id: productId, quantity: 1 });
  }

  saveCart();
  renderCart();
}

function updateQuantity(productId, delta) {
  const item = cart.find((entry) => entry.id === productId);
  if (!item) {
    return;
  }

  item.quantity += delta;
  if (item.quantity <= 0) {
    cart = cart.filter((entry) => entry.id !== productId);
  }

  saveCart();
  renderCart();
}

function removeFromCart(productId) {
  cart = cart.filter((item) => item.id !== productId);
  saveCart();
  renderCart();
}

function openQuoteRequest(productId) {
  const product = productMap.get(productId);
  if (!product) {
    return;
  }

  const subject = encodeURIComponent(`Quote Request - ${product.name}`);
  const body = encodeURIComponent(
    `Hello Intellium Digital,\n\nI would like to request a quotation for:\n${product.name}\n\nPlease send me the next steps and scope requirements.\n\nThank you.`
  );
  window.location.href = `mailto:intelliumdigital@gmail.com?subject=${subject}&body=${body}`;
}

async function startCatalogCheckout() {
  const items = getCartDetailedItems();
  if (!items.length || !catalogCheckoutBtn) {
    return;
  }

  const originalText = catalogCheckoutBtn.textContent;
  catalogCheckoutBtn.disabled = true;
  catalogCheckoutBtn.textContent = "Creating secure Maya checkout...";

  try {
    const response = await fetch("/api/create-maya-checkout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        items: items.map((item) => ({ id: item.id, quantity: item.quantity })),
        totalAmount: getCartSubtotalValue(),
        customerNote: customerNoteInput ? customerNoteInput.value.trim() : ""
      })
    });

    const data = await response.json();
    if (!response.ok || !data.checkoutUrl) {
      throw new Error(data.error || "Unable to create Maya Checkout session.");
    }

    window.location.href = data.checkoutUrl;
  } catch (error) {
    console.error(error);
    alert("We could not create the Maya Checkout link. Please message Intellium Digital first or try again later.");
    catalogCheckoutBtn.disabled = false;
    catalogCheckoutBtn.textContent = originalText;
  }
}

document.querySelectorAll(".maya-pay-btn").forEach((button) => {
  button.addEventListener("click", async () => {
    const originalHtml = button.innerHTML;
    const packageName = button.dataset.name;
    const amount = Number(button.dataset.amount);

    button.disabled = true;
    button.innerHTML = `
      <span class="btn-inner">
        <span class="icon-glass icon-neon icon-cyan button-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24">
            <path d="M5 7.5h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2Z"></path>
            <path d="M3 10.5h18"></path>
            <path d="m12 13.5 2 2 4-4"></path>
          </svg>
        </span>
        <span>Creating secure Maya checkout...</span>
      </span>
    `;

    try {
      const response = await fetch("/api/create-maya-checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ packageName, amount })
      });

      const data = await response.json();

      if (!response.ok || !data.checkoutUrl) {
        throw new Error(data.error || "Unable to create Maya Checkout session.");
      }

      window.location.href = data.checkoutUrl;
    } catch (error) {
      console.error(error);
      alert("We could not create the Maya Checkout link. Please message Intellium Digital first or try again later.");
      button.disabled = false;
      button.innerHTML = originalHtml;
    }
  });
});

if (catalogFilters) {
  catalogFilters.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement) || !target.matches("[data-filter]")) {
      return;
    }

    currentFilter = target.dataset.filter || "All";
    catalogFilters.querySelectorAll("[data-filter]").forEach((button) => {
      button.classList.toggle("active", button === target);
    });
    renderCatalog();
  });
}

if (catalogGrid) {
  catalogGrid.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) {
      return;
    }

    const addId = target.getAttribute("data-add-id");
    const quoteId = target.getAttribute("data-quote-id");

    if (addId) {
      addToCart(addId);
    }

    if (quoteId) {
      openQuoteRequest(quoteId);
    }
  });
}

if (cartItemsContainer) {
  cartItemsContainer.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) {
      return;
    }

    const removeId = target.getAttribute("data-remove-id");
    const qtyId = target.getAttribute("data-qty-id");

    if (removeId) {
      removeFromCart(removeId);
    }

    if (qtyId) {
      const delta = Number(target.getAttribute("data-delta"));
      updateQuantity(qtyId, delta);
    }
  });
}

if (catalogCheckoutBtn) {
  catalogCheckoutBtn.addEventListener("click", startCatalogCheckout);
}

if (mobileCartToggleBtn && cartPanel) {
  mobileCartToggleBtn.addEventListener("click", () => {
    cartPanel.classList.toggle("open");
  });
}

if (cartCloseBtn && cartPanel) {
  cartCloseBtn.addEventListener("click", () => {
    cartPanel.classList.remove("open");
  });
}

if (customerNoteInput) {
  customerNoteInput.value = localStorage.getItem(CART_NOTE_STORAGE_KEY) || "";
  customerNoteInput.addEventListener("input", () => {
    localStorage.setItem(CART_NOTE_STORAGE_KEY, customerNoteInput.value);
  });
}

renderCatalog();
renderCart();
