import UIKit

// MARK: - Push Transition Manager

class PushTransitionManager: NSObject, UIViewControllerTransitioningDelegate {
    static let shared = PushTransitionManager()

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PushAnimator(isPresenting: true)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PushAnimator(isPresenting: false)
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        PushTransitionManager.shared.interactionController?.isInteracting == true
            ? PushTransitionManager.shared.interactionController
            : nil
    }

    var interactionController: SwipeBackInteractionController?
}

// MARK: - Push Animator

class PushAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)

        if isPresenting {
            guard let toView = transitionContext.view(forKey: .to) else { return }
            container.addSubview(toView)
            toView.frame = container.bounds.offsetBy(dx: container.bounds.width, dy: 0)

            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
                toView.frame = container.bounds
            } completion: { finished in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        } else {
            guard let fromView = transitionContext.view(forKey: .from),
                  let toView = transitionContext.view(forKey: .to) else { return }

            container.insertSubview(toView, belowSubview: fromView)
            toView.frame = container.bounds

            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
                fromView.frame = container.bounds.offsetBy(dx: container.bounds.width, dy: 0)
            } completion: { finished in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
}

// MARK: - Swipe Back Interaction Controller

class SwipeBackInteractionController: UIPercentDrivenInteractiveTransition {
    var isInteracting = false
    private weak var viewController: UIViewController?

    func attach(to viewController: UIViewController) {
        self.viewController = viewController
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        viewController.view.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let vc = viewController else { return }
        let translation = gesture.translation(in: vc.view)
        let progress = max(0, min(1, translation.x / vc.view.bounds.width))

        switch gesture.state {
        case .began:
            isInteracting = true
            PushTransitionManager.shared.interactionController = self
            vc.dismiss(animated: true)
        case .changed:
            update(progress)
        case .ended, .cancelled:
            isInteracting = false
            if progress > 0.3 || gesture.velocity(in: vc.view).x > 500 {
                finish()
            } else {
                cancel()
            }
            PushTransitionManager.shared.interactionController = nil
        default:
            break
        }
    }
}
