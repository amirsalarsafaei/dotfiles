use crate::bluetooth::aacp::AACPManager;
use std::sync::Arc;

pub struct DeviceManagers {
    aacp: Option<Arc<AACPManager>>,
    media_controller: Option<Arc<tokio::sync::Mutex<crate::media_controller::MediaController>>>,
}

impl DeviceManagers {
    /// Reserve a HashMap slot before async init starts so concurrent
    /// connection events can detect the in-progress claim.
    pub fn placeholder() -> Self {
        Self {
            aacp: None,
            media_controller: None,
        }
    }

    pub fn with_aacp(aacp: AACPManager) -> Self {
        Self {
            aacp: Some(Arc::new(aacp)),
            media_controller: None,
        }
    }

    pub fn set_aacp(&mut self, manager: AACPManager) {
        self.aacp = Some(Arc::new(manager));
    }

    pub fn get_aacp(&self) -> Option<Arc<AACPManager>> {
        self.aacp.clone()
    }

    pub fn set_media_controller(
        &mut self,
        controller: Arc<tokio::sync::Mutex<crate::media_controller::MediaController>>,
    ) {
        self.media_controller = Some(controller);
    }

    pub fn get_media_controller(
        &self,
    ) -> Option<Arc<tokio::sync::Mutex<crate::media_controller::MediaController>>> {
        self.media_controller.clone()
    }
}
