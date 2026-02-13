"""
Artist Revenue Management System - Main Application
MDL018 - Data Organization and Management
"""

import streamlit as st
import os
from utils.db import get_db_connection, test_connection

# Page configuration
st.set_page_config(
    page_title="Artist Revenue Management",
    page_icon="🎵",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
def load_css():
    css_file = os.path.join(os.path.dirname(__file__), "assets", "style.css")
    if os.path.exists(css_file):
        with open(css_file) as f:
            st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

load_css()

# Main page
def main():
    st.title("🎵 Artist Revenue Management System")
    st.markdown("---")
    
    # Database connection status
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if test_connection():
            st.success("✅ Database Connected")
        else:
            st.error("❌ Database Connection Failed")
    
    with col2:
        st.info("📊 PostgreSQL 16")
    
    with col3:
        st.info("🐳 Docker Environment")
    
    st.markdown("---")
    
    # Welcome content
    st.header("Welcome!")
    st.write("""
    This system manages artist revenue from multiple sources including:
    - 🎧 **Streaming** platforms
    - 💿 **Download** sales
    - 🎤 **Live shows** and bookings
    
    ### Features:
    - Artist and label management
    - Album and track catalog
    - Revenue tracking and analytics
    - Contract management and revenue splits
    - Booking and venue management
    
    ### Navigation:
    Use the sidebar to navigate between different sections:
    - **Dashboard**: Overview and statistics
    - **Artists**: Artist profiles and management
    - **Revenue**: Revenue analytics and reports
    """)
    
    st.markdown("---")
    st.caption("MDL018 - Data Organization and Management | University of Science - VNU-HCM")

if __name__ == "__main__":
    main()
