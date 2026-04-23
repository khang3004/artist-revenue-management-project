
import streamlit as st

def apply_apple_style():
    """
    Apply Apple Liquid Glass (macOS 26 style) UI to Streamlit.
    """
    st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

    :root {
        --apple-bg: rgba(28, 28, 30, 0.7);
        --apple-card: rgba(44, 44, 46, 0.5);
        --apple-border: rgba(255, 255, 255, 0.1);
        --apple-text: #FFFFFF;
        --apple-accent: #0A84FF;
        --glass-blur: blur(20px);
    }

    /* Main App Background */
    .stApp {
        background: radial-gradient(circle at top left, #1c1c1e, #000000) !important;
        color: var(--apple-text);
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }

    /* Card Styling for st.container */
    [data-testid="stVerticalBlockBorderWrapper"] > div > [data-testid="stVerticalBlock"] {
        background: var(--apple-card);
        backdrop-filter: var(--glass-blur);
        border-radius: 18px;
        padding: 1.5rem;
        border: 1px solid var(--apple-border);
        box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
        margin-bottom: 1rem;
    }

    /* Sidebar Styling */
    section[data-testid="stSidebar"] {
        background-color: rgba(28, 28, 30, 0.4) !important;
        backdrop-filter: var(--glass-blur);
        border-right: 1px solid var(--apple-border);
    }

    /* Metric Styling */
    div[data-testid="stMetric"] {
        background: rgba(255, 255, 255, 0.05);
        padding: 15px;
        border-radius: 12px;
        border: 1px solid var(--apple-border);
    }

    /* Button Styling */
    .stButton > button {
        background: var(--apple-accent);
        color: white;
        border-radius: 10px;
        border: none;
        padding: 10px 20px;
        font-weight: 600;
        transition: all 0.3s ease;
    }

    .stButton > button:hover {
        opacity: 0.8;
        transform: translateY(-2px);
    }

    /* Inputs and Selectboxes */
    div[data-baseweb="select"] > div {
        background-color: rgba(255, 255, 255, 0.05) !important;
        border-radius: 10px !important;
        border: 1px solid var(--apple-border) !important;
    }

    /* Headings */
    h1, h2, h3 {
        font-weight: 700 !important;
        letter-spacing: -0.5px !important;
    }

    /* Dataframe Styling */
    .stDataFrame {
        border-radius: 12px;
        overflow: hidden;
        border: 1px solid var(--apple-border);
    }

    /* Divider */
    hr {
        border-top: 1px solid var(--apple-border);
    }

    /* Tab styling */
    button[data-baseweb="tab"] {
        font-weight: 600;
    }

    /* Progress bar */
    div[data-testid="stProgress"] > div > div > div {
        background-color: var(--apple-accent);
    }

    </style>
    """, unsafe_allow_html=True)

def card_container():
    """Helper for card-like layout"""
    return st.container()
