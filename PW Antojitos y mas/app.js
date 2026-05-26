/**
 * ================================================================
 * SABOR DE LA VIDA — app.js
 * Descripción: Lógica funcional de la página web del restaurante.
 *
 * Módulos incluidos:
 *  1. NAVBAR         — Scroll effect + menú hamburguesa móvil
 *  2. CARRITO        — Agregar, quitar y gestionar items del pedido
 *  3. BEBIDAS TABS   — Filtro de categorías de bebidas
 *  4. WHATSAPP       — Generación del mensaje y enlace de pedido
 * ================================================================
 */

'use strict';


/* ================================================================
   MÓDULO 1: NAVBAR
   Descripción: Agrega clase .navbar--scrolled al scroll y maneja
                el menú hamburguesa en dispositivos móviles.
   ================================================================ */

(function inicializarNavbar() {

  /** Referencia al elemento navbar */
  const navbar    = document.getElementById('navbar');
  /** Botón hamburguesa */
  const navToggle = document.getElementById('navToggle');
  /** Menú de navegación */
  const navMenu   = document.getElementById('navMenu');

  // -- Efecto scroll: añadir fondo sólido al navbar --
  window.addEventListener('scroll', function manejarScroll() {
    if (window.scrollY > 60) {
      navbar.classList.add('navbar--scrolled');
    } else {
      navbar.classList.remove('navbar--scrolled');
    }
  });

  // -- Hamburguesa: toggle del menú móvil --
  navToggle.addEventListener('click', function toggleMenu() {
    const estaAbierto = navMenu.classList.toggle('navbar__menu--open');
    navToggle.setAttribute('aria-expanded', String(estaAbierto));
    // Bloquear scroll del body cuando el menú está abierto
    document.body.style.overflow = estaAbierto ? 'hidden' : '';
  });

  // -- Cerrar menú al hacer clic en un enlace --
  navMenu.querySelectorAll('.navbar__link').forEach(function (enlace) {
    enlace.addEventListener('click', function cerrarMenu() {
      navMenu.classList.remove('navbar__menu--open');
      navToggle.setAttribute('aria-expanded', 'false');
      document.body.style.overflow = '';
    });
  });

})();


/* ================================================================
   MÓDULO 2: CARRITO DE PEDIDO
   Descripción: Gestiona el carrito de pedido del restaurante.
                Permite agregar/quitar items, calcular el total
                y enviar el pedido por WhatsApp.

   Estructura de estado:
     carrito = [
       { id: Number, nombre: String, precio: Number, cantidad: Number }
     ]
   ================================================================ */

(function inicializarCarrito() {

  // ---- Referencias al DOM ----
  const panelCarrito    = document.getElementById('carrito');
  const overlayCarrito  = document.getElementById('carritoOverlay');
  const btnCerrar       = document.getElementById('carritoClose');
  const listaItems      = document.getElementById('carritoItems');
  const totalDisplay    = document.getElementById('carritoTotal');
  const contadorFab     = document.getElementById('carritoCount');
  const fab             = document.getElementById('carritoFab');
  const btnEnviar       = document.getElementById('carritoEnviar');
  const btnLimpiar      = document.getElementById('carritoLimpiar');

  /** @type {Array<{id:number, nombre:string, precio:number, cantidad:number}>} */
  let estado = [];

  // ---- Funciones privadas ----

  /**
   * abrirCarrito
   * Muestra el panel lateral y el overlay oscuro.
   */
  function abrirCarrito() {
    panelCarrito.classList.add('carrito--open');
    panelCarrito.setAttribute('aria-hidden', 'false');
    overlayCarrito.classList.add('carrito__overlay--visible');
  }

  /**
   * cerrarCarrito
   * Oculta el panel lateral y el overlay.
   */
  function cerrarCarrito() {
    panelCarrito.classList.remove('carrito--open');
    panelCarrito.setAttribute('aria-hidden', 'true');
    overlayCarrito.classList.remove('carrito__overlay--visible');
  }

  /**
   * calcularTotal
   * Suma el precio × cantidad de todos los items del carrito.
   * @returns {number} Total en córdobas
   */
  function calcularTotal() {
    return estado.reduce(function (acc, item) {
      return acc + (item.precio * item.cantidad);
    }, 0);
  }

  /**
   * actualizarContador
   * Actualiza el badge del botón flotante con la cantidad de items.
   */
  function actualizarContador() {
    const totalItems = estado.reduce(function (acc, item) {
      return acc + item.cantidad;
    }, 0);
    contadorFab.textContent = totalItems;
  }

  /**
   * renderizarCarrito
   * Vacía y vuelve a renderizar la lista de items del carrito.
   * También actualiza el total y el contador del FAB.
   */
  function renderizarCarrito() {
    // Limpiar lista
    listaItems.innerHTML = '';

    if (estado.length === 0) {
      // Mensaje de carrito vacío
      const li = document.createElement('li');
      li.style.cssText = 'text-align:center;color:#b8a080;padding:2rem;font-size:0.9rem;';
      li.textContent = 'No hay items en tu pedido todavía.';
      listaItems.appendChild(li);
    } else {
      // Renderizar cada item
      estado.forEach(function (item) {
        const li = document.createElement('li');
        li.className = 'carrito-item';
        li.setAttribute('data-id', item.id);
        li.innerHTML = `
          <span class="carrito-item__name">${item.nombre}</span>
          <div class="carrito-item__qty">
            <button class="carrito-item__qty-btn"
                    aria-label="Quitar uno de ${item.nombre}"
                    onclick="cambiarCantidad(${item.id}, -1)">−</button>
            <span class="carrito-item__count">${item.cantidad}</span>
            <button class="carrito-item__qty-btn"
                    aria-label="Agregar uno de ${item.nombre}"
                    onclick="cambiarCantidad(${item.id}, 1)">+</button>
          </div>
          <span class="carrito-item__price">C$ ${item.precio * item.cantidad}</span>
        `;
        listaItems.appendChild(li);
      });
    }

    // Actualizar total y contador
    totalDisplay.textContent = `C$ ${calcularTotal()}`;
    actualizarContador();
  }

  // ---- API Pública (expuesta en window para onclick inline) ----

  /**
   * agregarAlCarrito
   * Agrega un producto al carrito. Si ya existe, incrementa la cantidad.
   * @param {number} id       - ID único del producto
   * @param {string} nombre   - Nombre del producto
   * @param {number} precio   - Precio en córdobas
   */
  window.agregarAlCarrito = function agregarAlCarrito(id, nombre, precio) {
    const itemExistente = estado.find(function (item) {
      return item.id === id;
    });

    if (itemExistente) {
      // Si ya existe, solo aumentamos la cantidad
      itemExistente.cantidad += 1;
    } else {
      // Si no existe, lo añadimos al arreglo
      estado.push({ id: id, nombre: nombre, precio: precio, cantidad: 1 });
    }

    renderizarCarrito();
    abrirCarrito();
  };

  /**
   * cambiarCantidad
   * Incrementa o decrementa la cantidad de un item en el carrito.
   * Si la cantidad llega a 0, elimina el item.
   * @param {number} id     - ID del producto
   * @param {number} delta  - +1 o -1
   */
  window.cambiarCantidad = function cambiarCantidad(id, delta) {
    const indice = estado.findIndex(function (item) {
      return item.id === id;
    });

    if (indice === -1) return;

    estado[indice].cantidad += delta;

    if (estado[indice].cantidad <= 0) {
      // Eliminar del arreglo si llega a 0
      estado.splice(indice, 1);
    }

    renderizarCarrito();
  };

  // ---- Event Listeners ----

  // Cerrar con el botón X
  btnCerrar.addEventListener('click', cerrarCarrito);

  // Cerrar al hacer clic en el overlay
  overlayCarrito.addEventListener('click', cerrarCarrito);

  // Abrir carrito al hacer clic en el FAB
  fab.addEventListener('click', abrirCarrito);

  // Limpiar todo el carrito
  btnLimpiar.addEventListener('click', function limpiarCarrito() {
    if (estado.length === 0) return;
    if (confirm('¿Seguro que deseas limpiar todo el carrito?')) {
      estado = [];
      renderizarCarrito();
    }
  });

  // Enviar pedido por WhatsApp
  btnEnviar.addEventListener('click', function enviarPorWhatsApp() {
    if (estado.length === 0) {
      alert('Agrega algunos productos antes de enviar tu pedido 😊');
      return;
    }

    const NUMERO_WHATSAPP = '50500000000'; // Cambiar por número real

    // Construir el mensaje de texto para WhatsApp
    let mensaje = '*Pedido — Sabor De La Vida* 🍽️\n\n';
    estado.forEach(function (item) {
      mensaje += `• ${item.nombre} x${item.cantidad} = C$ ${item.precio * item.cantidad}\n`;
    });
    mensaje += `\n*Total: C$ ${calcularTotal()}*\n\n_Enviado desde la web_`;

    // Codificar y abrir WhatsApp
    const url = `https://wa.me/${NUMERO_WHATSAPP}?text=${encodeURIComponent(mensaje)}`;
    window.open(url, '_blank', 'noopener,noreferrer');
  });

  // Render inicial (carrito vacío)
  renderizarCarrito();

})();


/* ================================================================
   MÓDULO 3: FILTRO DE BEBIDAS (TABS)
   Descripción: Filtra las tarjetas de bebidas por subcategoría.
                Usa data-subcategoria para comparar con el tab activo.
   ================================================================ */

(function inicializarFiltrosBebidas() {

  /** Contenedor de las cards de bebidas */
  const grid  = document.getElementById('bebidasGrid');
  /** Todos los botones tab */
  const tabs  = document.querySelectorAll('.bebidas__tab');

  if (!grid) return;

  tabs.forEach(function (tab) {
    tab.addEventListener('click', function manejarTab() {
      // Quitar clase activa de todos los tabs
      tabs.forEach(function (t) {
        t.classList.remove('bebidas__tab--active');
        t.setAttribute('aria-selected', 'false');
      });

      // Activar el tab clickeado
      tab.classList.add('bebidas__tab--active');
      tab.setAttribute('aria-selected', 'true');

      const filtro = tab.getAttribute('data-filter');

      // Mostrar/ocultar cards según el filtro
      const cards = grid.querySelectorAll('.bebida-card');
      cards.forEach(function (card) {
        if (filtro === 'todas') {
          // Mostrar todo
          card.style.display = '';
        } else {
          const sub = card.getAttribute('data-subcategoria');
          card.style.display = (sub === filtro) ? '' : 'none';
        }
      });
    });
  });

})();


/* ================================================================
   MÓDULO 4: ANIMACIÓN AL SCROLL (Intersection Observer)
   Descripción: Aplica animación fade-in a las secciones y tarjetas
                cuando entran en el viewport para una experiencia fluida.
   ================================================================ */

(function inicializarAnimacionesScroll() {

  // Si el navegador no soporta IntersectionObserver, salir
  if (!('IntersectionObserver' in window)) return;

  // Inyectar estilos de animación
  const style = document.createElement('style');
  style.textContent = `
    .anim-hidden {
      opacity: 0;
      transform: translateY(28px);
      transition: opacity 0.6s ease, transform 0.6s ease;
    }
    .anim-visible {
      opacity: 1;
      transform: translateY(0);
    }
  `;
  document.head.appendChild(style);

  // Seleccionar elementos a animar
  const elementos = document.querySelectorAll(
    '.product-card, .bebida-card, .extra-item, .antojito-hero, .menu-section__header, .extras__cta'
  );

  // Agregar clase inicial
  elementos.forEach(function (el, indice) {
    el.classList.add('anim-hidden');
    // Escalonar las animaciones dentro de la misma sección
    el.style.transitionDelay = ((indice % 4) * 80) + 'ms';
  });

  // Crear observer
  const observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add('anim-visible');
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.12   // Activar cuando el 12% del elemento es visible
  });

  elementos.forEach(function (el) {
    observer.observe(el);
  });

})();
