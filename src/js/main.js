// AWS Well-Architected Static Website JavaScript
// Performance-optimized, security-conscious, and accessibility-focused

'use strict';

// Main application object
const AWSArchitectureDemo = {
    // Configuration
    config: {
        animationDuration: 300,
        observerThreshold: 0.1,
        performanceEndpoint: '/api/metrics',
        version: '1.0.0'
    },

    // Initialize the application
    init() {
        console.log('🚀 AWS Architecture Demo initializing...');
        
        // Check browser support
        if (!this.checkBrowserSupport()) {
            console.warn('⚠️ Some features may not work in this browser');
        }

        // Initialize components
        this.setupIntersectionObserver();
        this.setupSmoothScrolling();
        this.setupPerformanceMonitoring();
        this.setupKeyboardNavigation();
        this.setupMobileInteractions();
        this.setupAccessibilityFeatures();
        this.setupErrorHandling();
        this.updateSystemStatus();
        
        console.log('✅ AWS Architecture Demo initialized successfully');
    },

    // Check browser support for key features
    checkBrowserSupport() {
        const features = {
            IntersectionObserver: 'IntersectionObserver' in window,
            fetch: 'fetch' in window,
            Promise: 'Promise' in window,
            localStorage: this.checkLocalStorage(),
            serviceWorker: 'serviceWorker' in navigator
        };

        const unsupportedFeatures = Object.entries(features)
            .filter(([feature, supported]) => !supported)
            .map(([feature]) => feature);

        if (unsupportedFeatures.length > 0) {
            console.warn('Unsupported features:', unsupportedFeatures);
            return false;
        }

        return true;
    },

    // Check localStorage availability
    checkLocalStorage() {
        try {
            const test = 'test';
            localStorage.setItem(test, test);
            localStorage.removeItem(test);
            return true;
        } catch (e) {
            return false;
        }
    },

    // Setup Intersection Observer for animations
    setupIntersectionObserver() {
        if (!('IntersectionObserver' in window)) {
            return;
        }

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('animate-in');
                    
                    // Optional: Stop observing after animation
                    observer.unobserve(entry.target);
                }
            });
        }, {
            threshold: this.config.observerThreshold,
            rootMargin: '0px 0px -50px 0px'
        });

        // Observe elements that should animate in
        const animateElements = document.querySelectorAll(
            '.architecture-item, .security-item, .metric-card, .monitoring-feature'
        );

        animateElements.forEach(el => {
            el.classList.add('animate-on-scroll');
            observer.observe(el);
        });
    },

    // Setup smooth scrolling for navigation links
    setupSmoothScrolling() {
        const navLinks = document.querySelectorAll('a[href^="#"]');
        
        navLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                
                const targetId = link.getAttribute('href').substring(1);
                const targetElement = document.getElementById(targetId);
                
                if (targetElement) {
                    targetElement.scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });
                    
                    // Update URL without triggering scroll
                    history.pushState(null, null, `#${targetId}`);
                    
                    // Focus target for accessibility
                    targetElement.setAttribute('tabindex', '-1');
                    targetElement.focus();
                }
            });
        });
    },

    // Setup performance monitoring
    setupPerformanceMonitoring() {
        // Log performance metrics
        window.addEventListener('load', () => {
            // Wait for all resources to load
            setTimeout(() => {
                this.logPerformanceMetrics();
            }, 1000);
        });

        // Monitor Core Web Vitals
        this.monitorCoreWebVitals();
    },

    // Log performance metrics
    logPerformanceMetrics() {
        if (!('performance' in window) || !performance.timing) {
            return;
        }

        const timing = performance.timing;
        const metrics = {
            // Page load metrics
            pageLoadTime: timing.loadEventEnd - timing.navigationStart,
            domContentLoaded: timing.domContentLoadedEventEnd - timing.navigationStart,
            domComplete: timing.domComplete - timing.navigationStart,
            
            // Network metrics
            connectTime: timing.connectEnd - timing.connectStart,
            requestTime: timing.responseEnd - timing.requestStart,
            
            // Render metrics
            domInteractive: timing.domInteractive - timing.navigationStart,
            
            // Browser info
            userAgent: navigator.userAgent,
            timestamp: new Date().toISOString()
        };

        console.log('📊 Performance Metrics:', metrics);

        // Store metrics for potential upload
        this.storeMetrics(metrics);
    },

    // Monitor Core Web Vitals
    monitorCoreWebVitals() {
        // Largest Contentful Paint (LCP)
        if ('PerformanceObserver' in window) {
            try {
                const lcpObserver = new PerformanceObserver((list) => {
                    const entries = list.getEntries();
                    const lastEntry = entries[entries.length - 1];
                    console.log('📈 LCP:', lastEntry.startTime);
                });
                lcpObserver.observe({ entryTypes: ['largest-contentful-paint'] });

                // First Input Delay (FID)
                const fidObserver = new PerformanceObserver((list) => {
                    list.getEntries().forEach(entry => {
                        console.log('⚡ FID:', entry.processingStart - entry.startTime);
                    });
                });
                fidObserver.observe({ entryTypes: ['first-input'] });

                // Cumulative Layout Shift (CLS)
                let clsValue = 0;
                const clsObserver = new PerformanceObserver((list) => {
                    list.getEntries().forEach(entry => {
                        if (!entry.hadRecentInput) {
                            clsValue += entry.value;
                        }
                    });
                    console.log('📏 CLS:', clsValue);
                });
                clsObserver.observe({ entryTypes: ['layout-shift'] });

            } catch (error) {
                console.warn('Performance observation not supported:', error);
            }
        }
    },

    // Store metrics in localStorage
    storeMetrics(metrics) {
        if (!this.checkLocalStorage()) {
            return;
        }

        try {
            const existingMetrics = JSON.parse(localStorage.getItem('performanceMetrics') || '[]');
            existingMetrics.push(metrics);
            
            // Keep only last 10 entries
            const recentMetrics = existingMetrics.slice(-10);
            localStorage.setItem('performanceMetrics', JSON.stringify(recentMetrics));
        } catch (error) {
            console.warn('Failed to store metrics:', error);
        }
    },

    // Setup keyboard navigation
    setupKeyboardNavigation() {
        // Handle keyboard navigation
        document.addEventListener('keydown', (e) => {
            // Skip link activation
            if (e.key === 'Tab' && e.target.classList.contains('skip-link')) {
                return;
            }

            // ESC to close any open dialogs or return to top
            if (e.key === 'Escape') {
                document.activeElement.blur();
                window.scrollTo({ top: 0, behavior: 'smooth' });
                this.announceToScreenReader('Returned to top of page', 'polite');
            }

            // Arrow key navigation for section links
            if (e.target.matches('.nav-list a')) {
                const navLinks = Array.from(document.querySelectorAll('.nav-list a'));
                const currentIndex = navLinks.indexOf(e.target);

                if (e.key === 'ArrowLeft' && currentIndex > 0) {
                    e.preventDefault();
                    navLinks[currentIndex - 1].focus();
                } else if (e.key === 'ArrowRight' && currentIndex < navLinks.length - 1) {
                    e.preventDefault();
                    navLinks[currentIndex + 1].focus();
                }
            }

            // Keyboard shortcuts
            if (e.ctrlKey || e.metaKey) {
                switch (e.key) {
                    case 'h':
                        e.preventDefault();
                        this.showKeyboardHelp();
                        break;
                    case '1':
                        e.preventDefault();
                        this.navigateToSection('architecture');
                        break;
                    case '2':
                        e.preventDefault();
                        this.navigateToSection('security');
                        break;
                    case '3':
                        e.preventDefault();
                        this.navigateToSection('performance');
                        break;
                    case '4':
                        e.preventDefault();
                        this.navigateToSection('monitoring');
                        break;
                }
            }
        });
    },

    // Setup mobile interactions
    setupMobileInteractions() {
        // Touch support detection
        const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
        
        if (!isTouchDevice) {
            return;
        }

        // Add touch interaction for architecture items
        const interactiveElements = document.querySelectorAll(
            '.architecture-item, .security-item, .metric-card, .monitoring-feature'
        );

        interactiveElements.forEach(element => {
            this.setupTouchInteractions(element);
        });

        // Setup diagram zoom/pan for mobile
        this.setupMobileDiagramInteractions();
    },

    // Setup touch interactions for elements
    setupTouchInteractions(element) {
        let touchStartTime = 0;
        let touchMoved = false;

        element.addEventListener('touchstart', (e) => {
            touchStartTime = Date.now();
            touchMoved = false;
        }, { passive: true });

        element.addEventListener('touchmove', () => {
            touchMoved = true;
        }, { passive: true });

        element.addEventListener('touchend', (e) => {
            const touchDuration = Date.now() - touchStartTime;
            
            // If it's a quick tap (< 200ms) and no movement, treat as click
            if (touchDuration < 200 && !touchMoved) {
                this.handleElementInteraction(element);
            }
        });
    },

    // Setup mobile diagram interactions
    setupMobileDiagramInteractions() {
        // Create zoom overlay for complex diagrams
        const diagramContainers = document.querySelectorAll('.architecture-grid, .security-grid, .performance-metrics');
        
        diagramContainers.forEach(container => {
            this.setupZoomInteraction(container);
        });
    },

    // Setup zoom interaction for diagram containers
    setupZoomInteraction(container) {
        // Add zoom button for mobile users
        const zoomButton = document.createElement('button');
        zoomButton.className = 'mobile-zoom-btn';
        zoomButton.innerHTML = '🔍 Zoom to view details';
        zoomButton.setAttribute('aria-label', 'Zoom in to view diagram details');
        
        // Insert zoom button before container
        container.parentNode.insertBefore(zoomButton, container);

        zoomButton.addEventListener('click', () => {
            this.openZoomModal(container);
        });
    },

    // Open zoom modal for better mobile viewing
    openZoomModal(container) {
        const modal = document.createElement('div');
        modal.className = 'zoom-modal';
        modal.innerHTML = `
            <div class="zoom-modal-content">
                <button class="zoom-close" aria-label="Close zoom view">×</button>
                <div class="zoom-container">
                    ${container.outerHTML}
                </div>
            </div>
        `;

        document.body.appendChild(modal);
        document.body.style.overflow = 'hidden';

        // Focus management
        const closeBtn = modal.querySelector('.zoom-close');
        closeBtn.focus();

        // Close modal handlers
        const closeModal = () => {
            document.body.removeChild(modal);
            document.body.style.overflow = '';
            this.announceToScreenReader('Zoom view closed', 'polite');
        };

        closeBtn.addEventListener('click', closeModal);
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeModal();
        });

        document.addEventListener('keydown', function escHandler(e) {
            if (e.key === 'Escape') {
                closeModal();
                document.removeEventListener('keydown', escHandler);
            }
        });

        this.announceToScreenReader('Zoom view opened. Press Escape to close.', 'polite');
    },

    // Setup accessibility features
    setupAccessibilityFeatures() {
        // Add ARIA live region support
        this.ariaLiveRegions = {
            polite: document.getElementById('status-announcements'),
            assertive: document.getElementById('alert-announcements')
        };

        // Enhanced focus management
        this.setupFocusManagement();
        
        // Add aria-current to navigation
        this.updateAriaCurrentNavigation();
        
        // Setup breadcrumb navigation
        this.setupBreadcrumbNavigation();
    },

    // Setup focus management
    setupFocusManagement() {
        // Track focus for better UX
        let lastFocusedElement = null;

        document.addEventListener('focusin', (e) => {
            lastFocusedElement = e.target;
        });

        // Handle focus restoration
        window.addEventListener('hashchange', () => {
            const target = document.getElementById(location.hash.substring(1));
            if (target) {
                target.setAttribute('tabindex', '-1');
                target.focus();
                this.announceToScreenReader(`Navigated to ${target.textContent || target.id}`, 'polite');
            }
        });
    },

    // Update aria-current for navigation
    updateAriaCurrentNavigation() {
        const navLinks = document.querySelectorAll('.nav-list a[href^="#"]');
        
        const updateCurrent = () => {
            navLinks.forEach(link => {
                link.removeAttribute('aria-current');
                const targetId = link.getAttribute('href').substring(1);
                const target = document.getElementById(targetId);
                
                if (target && this.isElementInViewport(target)) {
                    link.setAttribute('aria-current', 'page');
                }
            });
        };

        // Update on scroll (throttled)
        window.addEventListener('scroll', this.throttle(updateCurrent, 200));
        updateCurrent(); // Initial call
    },

    // Check if element is in viewport
    isElementInViewport(element) {
        const rect = element.getBoundingClientRect();
        return (
            rect.top >= 0 &&
            rect.top <= window.innerHeight * 0.5
        );
    },

    // Handle element interaction
    handleElementInteraction(element) {
        // Add visual feedback
        element.classList.add('interaction-active');
        setTimeout(() => {
            element.classList.remove('interaction-active');
        }, 150);

        // Announce interaction to screen readers
        const heading = element.querySelector('h3');
        if (heading) {
            this.announceToScreenReader(`Selected ${heading.textContent}`, 'polite');
        }
    },

    // Navigate to section with announcement
    navigateToSection(sectionId) {
        const section = document.getElementById(sectionId);
        if (section) {
            section.scrollIntoView({ behavior: 'smooth', block: 'start' });
            section.setAttribute('tabindex', '-1');
            section.focus();
            
            const heading = section.querySelector('h2');
            const sectionName = heading ? heading.textContent : sectionId;
            this.announceToScreenReader(`Navigated to ${sectionName} section`, 'polite');
        }
    },

    // Show keyboard help
    showKeyboardHelp() {
        const helpText = `
            Keyboard shortcuts:
            Ctrl+H: Show this help
            Ctrl+1: Architecture section
            Ctrl+2: Security section
            Ctrl+3: Performance section
            Ctrl+4: Monitoring section
            Escape: Return to top
            Tab: Navigate through interactive elements
            Arrow keys: Navigate within navigation menu
        `;
        
        this.announceToScreenReader(helpText, 'assertive');
        console.log('🎹 Keyboard Help:', helpText);
    },

    // Announce to screen reader
    announceToScreenReader(message, priority = 'polite') {
        const region = this.ariaLiveRegions && this.ariaLiveRegions[priority];
        if (region) {
            region.textContent = message;
            // Clear after announcement
            setTimeout(() => {
                region.textContent = '';
            }, 1000);
        }
    },

    // Setup breadcrumb navigation
    setupBreadcrumbNavigation() {
        const currentSectionElement = document.getElementById('current-section');
        const homeLink = document.querySelector('.breadcrumb-list a[href="#main-content"]');
        
        if (!currentSectionElement || !homeLink) {
            return;
        }

        // Section mapping
        const sectionMap = {
            'architecture': 'Architecture Overview',
            'security': 'Security Features', 
            'performance': 'Performance Optimization',
            'monitoring': 'Monitoring & Observability'
        };

        // Update breadcrumb based on current section
        const updateBreadcrumb = () => {
            const currentSection = this.getCurrentSection();
            
            if (currentSection && sectionMap[currentSection]) {
                currentSectionElement.textContent = sectionMap[currentSection];
                currentSectionElement.classList.add('active');
                currentSectionElement.setAttribute('aria-hidden', 'false');
                homeLink.removeAttribute('aria-current');
            } else {
                currentSectionElement.classList.remove('active');
                currentSectionElement.setAttribute('aria-hidden', 'true');
                homeLink.setAttribute('aria-current', 'page');
            }
        };

        // Update on scroll (throttled)
        window.addEventListener('scroll', this.throttle(updateBreadcrumb, 200));
        
        // Update on hash change
        window.addEventListener('hashchange', updateBreadcrumb);
        
        // Initial update
        updateBreadcrumb();
    },

    // Get current section based on scroll position
    getCurrentSection() {
        const sections = ['architecture', 'security', 'performance', 'monitoring'];
        
        // Check hash first
        if (location.hash) {
            const hashSection = location.hash.substring(1);
            if (sections.includes(hashSection)) {
                return hashSection;
            }
        }

        // Check scroll position
        for (const sectionId of sections) {
            const section = document.getElementById(sectionId);
            if (section && this.isElementInViewport(section)) {
                return sectionId;
            }
        }

        return null;
    },

    // Setup global error handling
    setupErrorHandling() {
        // Global error handler
        window.addEventListener('error', (e) => {
            console.error('🚨 JavaScript Error:', {
                message: e.message,
                filename: e.filename,
                line: e.lineno,
                column: e.colno,
                error: e.error,
                timestamp: new Date().toISOString()
            });

            // Don't show errors to users in production
            if (location.hostname !== 'localhost' && location.hostname !== '127.0.0.1') {
                e.preventDefault();
            }
        });

        // Unhandled promise rejection handler
        window.addEventListener('unhandledrejection', (e) => {
            console.error('🚨 Unhandled Promise Rejection:', {
                reason: e.reason,
                promise: e.promise,
                timestamp: new Date().toISOString()
            });
        });
    },

    // Update system status indicators
    updateSystemStatus() {
        const statusElements = {
            'performance-status': this.checkPerformanceStatus(),
            'security-status': this.checkSecurityStatus(),
            'uptime-status': this.checkUptimeStatus()
        };

        Object.entries(statusElements).forEach(([id, status]) => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = status.text;
                element.className = `status-${status.level}`;
            }
        });
    },

    // Check performance status
    checkPerformanceStatus() {
        const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
        
        if (connection) {
            const effectiveType = connection.effectiveType;
            if (effectiveType === '4g') {
                return { text: 'Excellent', level: 'good' };
            } else if (effectiveType === '3g') {
                return { text: 'Good', level: 'ok' };
            } else {
                return { text: 'Limited', level: 'warning' };
            }
        }
        
        return { text: 'Unknown', level: 'neutral' };
    },

    // Check security status
    checkSecurityStatus() {
        const isHTTPS = location.protocol === 'https:';
        const hasSecureContext = window.isSecureContext;
        
        if (isHTTPS && hasSecureContext) {
            return { text: 'A+', level: 'good' };
        } else if (isHTTPS) {
            return { text: 'A', level: 'ok' };
        } else {
            return { text: 'C', level: 'warning' };
        }
    },

    // Check uptime status (simulated)
    checkUptimeStatus() {
        // In a real application, this would call an API
        return { text: '99.9%', level: 'good' };
    },

    // Utility function to debounce events
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    // Utility function to throttle events
    throttle(func, limit) {
        let inThrottle;
        return function(...args) {
            if (!inThrottle) {
                func.apply(this, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    }
};

// Add CSS for animations
const animationCSS = `
    .animate-on-scroll {
        opacity: 0;
        transform: translateY(20px);
        transition: opacity 0.6s ease-out, transform 0.6s ease-out;
    }
    
    .animate-on-scroll.animate-in {
        opacity: 1;
        transform: translateY(0);
    }
    
    .status-good { color: #4CAF50; }
    .status-ok { color: #2196F3; }
    .status-warning { color: #FF9800; }
    .status-error { color: #F44336; }
    .status-neutral { color: #757575; }
    
    /* Mobile Interaction Styles */
    .mobile-zoom-btn {
        display: none;
        background: var(--primary-color);
        color: white;
        border: none;
        padding: 12px 16px;
        border-radius: var(--border-radius);
        font-size: var(--font-size-sm);
        font-weight: 600;
        margin: var(--spacing-md) 0;
        min-height: 48px;
        min-width: 48px;
        cursor: pointer;
        transition: all var(--transition-normal);
        box-shadow: var(--shadow-medium);
    }

    .mobile-zoom-btn:hover,
    .mobile-zoom-btn:focus {
        background: var(--accent-color);
        transform: translateY(-2px);
        box-shadow: var(--shadow-heavy);
    }

    .interaction-active {
        transform: scale(0.98);
        transition: transform 0.15s ease;
    }

    /* Zoom Modal Styles */
    .zoom-modal {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.9);
        z-index: 2000;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: var(--spacing-md);
    }

    .zoom-modal-content {
        background: white;
        border-radius: var(--border-radius);
        max-width: 95vw;
        max-height: 95vh;
        overflow: auto;
        position: relative;
    }

    .zoom-close {
        position: absolute;
        top: var(--spacing-sm);
        right: var(--spacing-sm);
        background: var(--primary-color);
        color: white;
        border: none;
        border-radius: 50%;
        width: 48px;
        height: 48px;
        font-size: var(--font-size-xl);
        font-weight: bold;
        cursor: pointer;
        z-index: 2001;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all var(--transition-normal);
    }

    .zoom-close:hover,
    .zoom-close:focus {
        background: var(--secondary-color);
        transform: scale(1.1);
    }

    .zoom-container {
        padding: var(--spacing-xl);
        padding-top: calc(var(--spacing-xl) + 48px);
    }

    /* Show mobile zoom buttons on touch devices */
    @media (max-width: 768px) {
        .mobile-zoom-btn {
            display: inline-block;
        }
    }
`;

// Inject animation CSS
const styleSheet = document.createElement('style');
styleSheet.textContent = animationCSS;
document.head.appendChild(styleSheet);

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => AWSArchitectureDemo.init());
} else {
    AWSArchitectureDemo.init();
}

// Export for potential use in other scripts
window.AWSArchitectureDemo = AWSArchitectureDemo;