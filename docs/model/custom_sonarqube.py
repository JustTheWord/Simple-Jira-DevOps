import os
import uuid
from pathlib import Path
from diagrams import Node

class SonarQube(Node):
    """
    Custom node for SonarQube, referencing a local PNG icon.
    Adjust _icon_dir to match your actual folder structure.
    """
    _provider = "onprem"
    _type = "monitoring"
    _icon_dir = "model/resources/onprem/monitoring"
    _icon = "sonarqube.png"  # Default icon file
    fontcolor = "#ffffff"

    def __init__(self, label="SonarQube", icon=None, **kwargs):
        """
        Initialize the SonarQube node.
        :param label: Node label.
        :param icon: Custom icon file name (optional).
        :param kwargs: Additional attributes.
        """
        # Use the custom icon if provided
        if icon:
            self._icon = icon
        super().__init__(label, **kwargs)

    def _load_icon(self):
        """
        Load the icon for the node, resolving the path.
        """
        basedir = Path(os.path.abspath(os.path.dirname(__file__)))
        icon_path = os.path.join(basedir.parent, self._icon_dir, self._icon)
        if not os.path.exists(icon_path):
            raise FileNotFoundError(f"Icon file not found: {icon_path}")
        return icon_path

# Example usage
if __name__ == "__main__":
    from diagrams import Diagram

    # Test the SonarQube custom node
    with Diagram("SonarQube Instance", show=False):
        sq = SonarQube()

