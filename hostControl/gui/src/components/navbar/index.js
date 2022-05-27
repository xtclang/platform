import React from "react";
import {Nav, NavLink, NavMenu} from "./NavbarElements";

const Navbar = () =>
  {
  return (
    <>
    <Nav>
      <NavMenu>
      <NavLink to="/" activestyle="true">
        Hosting
      </NavLink>
      <NavLink to="/about" activestyle="true">
        About
      </NavLink>
      <NavLink to="/contact" activestyle="true">
        Contact Us
      </NavLink>
      <NavLink to="/blogs" activestyle="true">
        Blogs
      </NavLink>
      <NavLink to="/sign-in" activestyle="true">
        Sign In
      </NavLink>
      </NavMenu>
    </Nav>
    </>
    );
  };

export default Navbar;