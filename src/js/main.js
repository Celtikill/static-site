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
        });
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